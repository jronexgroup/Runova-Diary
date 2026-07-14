import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

const apiKey = 'sk_myebg25x_rYQx70mU1I7yOorhnVTvP7cM';
const baseUrl = 'https://api.sarvam.ai';

Future<void> main(List<String> args) async {
  final imagePath = args.isNotEmpty ? args[0] : 'Bekar/Screenshot_2026-07-10-21-12-58-886_com.google.android.apps.nbu.paisa.user.jpg';

  final file = File(imagePath);
  if (!file.existsSync()) {
    print('ERROR: File not found: $imagePath');
    exit(1);
  }

  final bytes = await file.readAsBytes();
  print('Image: $imagePath (${bytes.length} bytes)');
  print('');

  // Step 1: OCR
  print('=== Step 1: OCR ===');
  final ocrStart = DateTime.now();
  final ocrText = await runOcr(bytes);
  final ocrTime = DateTime.now().difference(ocrStart).inMilliseconds;
  print('OCR time: ${ocrTime}ms (${ocrTime / 1000}s)');
  print('OCR text length: ${ocrText.length} chars');
  if (ocrText.isNotEmpty) {
    print('OCR text preview: ${ocrText.substring(0, ocrText.length > 200 ? 200 : ocrText.length)}');
  // Strip image descriptions and markdown image syntax
  final cleanText = ocrText
    .replaceAll(RegExp(r'!\[.*?\]\(data:image.*?\)'), '')
    .replaceAll(RegExp(r'\[IMAGE\]\s*\n\s*\n\s*\*[^*]*\*\s*'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
  print('OCR clean text (first 1000 chars): ${cleanText.length > 1000 ? cleanText.substring(0, 1000) : cleanText}');
  print('OCR clean text length: ${cleanText.length} chars');
  print('OCR clean text (first 1000 chars): ${cleanText.length > 1000 ? cleanText.substring(0, 1000) : cleanText}');
  print('OCR clean text length: ${cleanText.length} chars');
  }
  print('');

  if (ocrText.isEmpty) {
    print('OCR FAILED - no text extracted');
    exit(1);
  }

  // Clean OCR text - remove image descriptions to reduce token usage
  final lines = ocrText.split('\n');
  final cleanedLines = <String>[];
  bool skipNext = false;
  for (final line in lines) {
    if (line.contains('[IMAGE]')) {
      skipNext = true;
      continue;
    }
    if (skipNext && line.startsWith('*') && line.endsWith('*') && line.length > 20) {
      skipNext = false;
      continue;
    }
    skipNext = false;
    if (line.startsWith('*') && line.endsWith('*') && line.length > 20) continue;
    cleanedLines.add(line);
  }
  final cleanOcrText = cleanedLines.join('\n')
    .replaceAll(RegExp(r'!\[.*?\]\(data:image.*?\)'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
  print('Cleaned OCR text length: ${cleanOcrText.length} chars (was ${ocrText.length})');
  print('Cleaned OCR full text:');
  print(cleanOcrText);

  // Step 2: LLM extraction
  print('=== Step 2: LLM Extraction ===');
  final llmStart = DateTime.now();
  final fields = await extractWithLLM(cleanOcrText);
  final llmTime = DateTime.now().difference(llmStart).inMilliseconds;
  print('LLM time: ${llmTime}ms (${llmTime / 1000}s)');
  print('Extracted fields: $fields');
  print('');

  final totalTime = ocrTime + llmTime;
  print('=== RESULTS ===');
  print('OCR time: ${ocrTime}ms (${ocrTime / 1000}s)');
  print('LLM time: ${llmTime}ms (${llmTime / 1000}s)');
  print('Total time: ${totalTime}ms (${totalTime / 1000}s)');
  print('Extracted fields: $fields');
}

Future<String> runOcr(Uint8List imageBytes) async {
  final headers = {
    'api-subscription-key': apiKey,
    'Content-Type': 'application/json',
  };

  final createStart = DateTime.now();
  final createResp = await http.post(
    Uri.parse('$baseUrl/doc-digitization/job/v1'),
    headers: headers,
    body: jsonEncode({
      'job_parameters': {
        'language': 'en-IN',
        'output_format': 'md',
      },
    }),
  );
  print('  Create job: ${DateTime.now().difference(createStart).inMilliseconds}ms -> ${createResp.statusCode}');

  if (createResp.statusCode != 202) {
    print('  Create job failed: ${createResp.statusCode} ${createResp.body}');
    return '';
  }

  final createData = jsonDecode(createResp.body) as Map<String, dynamic>;
  final jobId = createData['job_id'] as String;
  print('  Job ID: $jobId');

  final uploadStart = DateTime.now();
  final uploadResp = await http.post(
    Uri.parse('$baseUrl/doc-digitization/job/v1/upload-files'),
    headers: headers,
    body: jsonEncode({
      'job_id': jobId,
      'files': ['document.jpg'],
    }),
  );
  print('  Get upload URLs: ${DateTime.now().difference(uploadStart).inMilliseconds}ms -> ${uploadResp.statusCode}');

  if (uploadResp.statusCode != 200) {
    print('  Get upload URLs failed: ${uploadResp.statusCode} ${uploadResp.body}');
    return '';
  }

  final uploadData = jsonDecode(uploadResp.body) as Map<String, dynamic>;
  final uploadUrls = uploadData['upload_urls'] as Map<String, dynamic>;
  final fileUrl = uploadUrls['document.jpg']?['file_url'] as String?;
  if (fileUrl == null) {
    print('  No upload URL returned');
    return '';
  }

  final putStart = DateTime.now();
  final putResp = await http.put(
    Uri.parse(fileUrl),
    headers: {'x-ms-blob-type': 'BlockBlob'},
    body: imageBytes,
  );
  print('  Upload file: ${DateTime.now().difference(putStart).inMilliseconds}ms -> ${putResp.statusCode}');

  if (putResp.statusCode != 201) {
    print('  File upload failed: ${putResp.statusCode}');
    return '';
  }

  final startResp = await http.post(
    Uri.parse('$baseUrl/doc-digitization/job/v1/$jobId/start'),
    headers: headers,
  );
  print('  Start job: ${startResp.statusCode}');

  if (startResp.statusCode != 202) {
    print('  Start job failed: ${startResp.statusCode} ${startResp.body}');
    return '';
  }

  // Poll for results
  String ocrText = '';
  for (int i = 0; i < 10; i++) {
    await Future.delayed(Duration(seconds: i < 3 ? 1 : 2));
    print('  Poll attempt ${i + 1}...');

    final statusResp = await http.get(
      Uri.parse('$baseUrl/doc-digitization/job/v1/$jobId/status'),
      headers: headers,
    );

    if (statusResp.statusCode != 200) continue;

    final statusData = jsonDecode(statusResp.body) as Map<String, dynamic>;
    final jobState = statusData['job_state'] as String? ?? '';
    print('  Job state: $jobState');

    if (jobState == 'Completed' || jobState == 'PartiallyCompleted') {
      final downloadResp = await http.post(
        Uri.parse('$baseUrl/doc-digitization/job/v1/$jobId/download-files'),
        headers: headers,
      );

      if (downloadResp.statusCode != 200) {
        print('  Download failed: ${downloadResp.statusCode}');
        return '';
      }

      final downloadData = jsonDecode(downloadResp.body) as Map<String, dynamic>;
      final dlUrls = downloadData['download_urls'] as Map<String, dynamic>;
      final dlUrl = dlUrls.values.first?['file_url'] as String?;
      if (dlUrl == null) return '';

      final zipResp = await http.get(Uri.parse(dlUrl));
      if (zipResp.statusCode != 200) return '';

      ocrText = extractTextFromZip(zipResp.bodyBytes);
      break;
    }

    if (jobState == 'Failed') {
      print('  OCR job failed');
      return '';
    }
  }

  return ocrText;
}

String extractTextFromZip(Uint8List zipBytes) {
  try {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final allText = StringBuffer();
    for (final file in archive) {
      if (file.isFile && !file.name.endsWith('.json')) {
        final content = String.fromCharCodes(file.content);
        allText.writeln(content);
      }
    }
    return allText.toString().trim();
  } catch (e) {
    print('ZIP parse error: $e');
    return '';
  }
}

Future<Map<String, dynamic>> extractWithLLM(String ocrText) async {
  try {
    final resp = await http.post(
      Uri.parse('$baseUrl/v1/chat/completions'),
      headers: {
        'api-subscription-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
          'model': 'sarvam-105b',
        'messages': [
          {
            'role': 'user',
            'content': 'Extract fields from this payment receipt text. Return ONLY a JSON object with these keys: customerName, amount, mobileNumber, transactionId, lastFourDigits, aadhaarNumber. If a field is not present, set it to null. Do NOT include any reasoning, explanation, or markdown formatting. Output ONLY the raw JSON object.\n\nText:\n$ocrText',
          },
        ],
        'max_tokens': 4000,
      }),
    );

    if (resp.statusCode != 200) {
      print('  LLM extraction failed: ${resp.statusCode} ${resp.body}');
      return {};
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      print('  No choices in response');
      print('  Raw response: ${resp.body}');
      return {};
    }

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.isEmpty) {
      print('  Empty content in response');
      print('  Raw response: ${resp.body}');
      return {};
    }

    print('  Raw LLM response: $content');

    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
    if (jsonMatch == null) {
      print('  No JSON found in LLM response');
      return {};
    }

    final fields = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      if (entry.value != null && entry.value.toString().isNotEmpty) {
        var val = entry.value.toString();
        if (entry.key == 'amount') {
          val = val.replaceAll(RegExp(r'[₹,\s]'), '');
        } else if (entry.key == 'lastFourDigits') {
          final last4 = RegExp(r'(\d{4})$').firstMatch(val);
          if (last4 != null) val = last4.group(1)!;
        }
        result[entry.key] = val;
      }
    }
    return result;
  } catch (e) {
    print('LLM extraction error: $e');
    return {};
  }
}
