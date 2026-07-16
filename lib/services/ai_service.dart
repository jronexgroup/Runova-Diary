import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/ai_settings.dart';
import '../models/bank_account.dart';

enum AiProgressStep {
  readingImage,
  compressing,
  sendingToAi,
  parsingResponse,
  fillingFields,
  done,
}

typedef AiProgressCallback = void Function(AiProgressStep step, String message);

class AiMonitorInfo {
  final String provider;
  final int keyIndex;
  final int totalKeys;
  final String? switchReason;

  const AiMonitorInfo({
    this.provider = 'unknown',
    this.keyIndex = 0,
    this.totalKeys = 0,
    this.switchReason,
  });

  String get displayLabel {
    if (provider == 'gemini') {
      return 'Gemini Key ${keyIndex + 1}/$totalKeys';
    }
    return 'Sarvam AI';
  }
}

typedef AiMonitorCallback = void Function(AiMonitorInfo info);

class AiResult {
  final Map<String, dynamic> fields;
  final String? error;
  final String provider;
  final bool switched;
  final AiMonitorInfo monitorInfo;

  AiResult({
    required this.fields,
    this.error,
    this.provider = 'unknown',
    this.switched = false,
    this.monitorInfo = const AiMonitorInfo(),
  });

  bool get isSuccess => fields.isNotEmpty && error == null;
  bool get isEmpty => fields.isEmpty && error == null;
}

class AiService {
  final AiSettings settings;
  static const _sarvamBaseUrl = 'https://api.sarvam.ai';
  static const _geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static final http.Client _httpClient = http.Client();
  final AiMonitorCallback? onMonitor;

  AiService(this.settings, {this.onMonitor});

  Future<AiResult> processDocument(String filePath, {AiProgressCallback? onProgress}) async {
    if (!settings.enabled) {
      debugPrint('[AI] AI disabled');
      return AiResult(fields: {}, error: 'AI is not configured. Enable in Settings > AI Settings.');
    }

    debugPrint('[AI] processDocument called with filePath: $filePath');

    try {
      onProgress?.call(AiProgressStep.readingImage, 'Reading image...');
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('[AI] File does not exist: $filePath');
        return AiResult(fields: {}, error: 'File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      debugPrint('[AI] Read ${bytes.length} bytes from file');

      // Try each Gemini key in order
      final geminiKeys = settings.geminiApiKeys.where((k) => k.isNotEmpty).toList();
      if (geminiKeys.isNotEmpty) {
        for (int i = 0; i < geminiKeys.length; i++) {
          final key = geminiKeys[i];
          debugPrint('[AI] Trying Gemini (key ${i + 1}/${geminiKeys.length})...');
          _emitMonitor('gemini', i, geminiKeys.length, i > 0 ? 'Gemini Key ${i + 1} (previous key failed)' : null);
          final geminiResult = await _processWithGemini(bytes, key, onProgress: onProgress);
          if (geminiResult.isSuccess) {
            debugPrint('[AI] Gemini (key ${i + 1}) succeeded');
            return geminiResult;
          }
          final isQuotaExhausted = geminiResult.error?.contains('429') == true ||
              geminiResult.error?.contains('rate limited') == true ||
              geminiResult.error?.contains('quota') == true ||
              geminiResult.error?.contains('RESOURCE_EXHAUSTED') == true;
          if (!isQuotaExhausted && i < geminiKeys.length - 1) {
            debugPrint('[AI] Gemini (key ${i + 1}) non-quota error: ${geminiResult.error}. Trying next key...');
          } else if (isQuotaExhausted) {
            debugPrint('[AI] Gemini (key ${i + 1}) quota exhausted. Trying next key...');
          }
        }
        // All Gemini keys exhausted
        debugPrint('[AI] All Gemini keys exhausted. Falling back to Sarvam...');
        _emitMonitor('sarvam', 0, 0, 'All Gemini keys exhausted');
      } else {
        debugPrint('[AI] No Gemini API keys configured, using Sarvam directly');
      }

      // Fallback to Sarvam
      if (settings.apiKey.isEmpty) {
        return AiResult(fields: {}, error: 'No AI provider available. Configure Gemini or Sarvam API key in Settings.');
      }

      final sarvamResult = await _processWithSarvam(bytes, filePath);
      if (settings.hasGeminiKeys) {
        return AiResult(
          fields: sarvamResult.fields,
          error: sarvamResult.error,
          provider: 'sarvam',
          switched: true,
          monitorInfo: AiMonitorInfo(provider: 'sarvam'),
        );
      }
      return sarvamResult;
    } catch (e) {
      debugPrint('[AI] processDocument exception: $e');
      return AiResult(fields: {}, error: 'AI processing error: $e');
    }
  }

  void _emitMonitor(String provider, int keyIndex, int totalKeys, [String? switchReason]) {
    final info = AiMonitorInfo(
      provider: provider,
      keyIndex: keyIndex,
      totalKeys: totalKeys,
      switchReason: switchReason,
    );
    onMonitor?.call(info);
  }

  Uint8List _compressImage(Uint8List bytes, {int maxDimension = 640, int quality = 50}) {
    try {
      final original = img.decodeImage(bytes);
      if (original == null) return bytes;

      img.Image resized = original;
      if (original.width > maxDimension || original.height > maxDimension) {
        resized = img.copyResize(original,
            width: original.width > original.height ? maxDimension : null,
            height: original.height >= original.width ? maxDimension : null,
            interpolation: img.Interpolation.nearest);
      }

      final compressed = img.encodeJpg(resized, quality: quality);
      debugPrint('[AI] Compressed image: ${bytes.length} -> ${compressed.length} bytes');
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('[AI] Image compression failed, using original: $e');
      return bytes;
    }
  }

  Future<AiResult> _processWithGemini(Uint8List imageBytes, String apiKey, {AiProgressCallback? onProgress}) async {
    onProgress?.call(AiProgressStep.compressing, 'Compressing image...');
    imageBytes = _compressImage(imageBytes);
    onProgress?.call(AiProgressStep.sendingToAi, 'Sending to Gemini...');

    try {
      final base64Image = base64Encode(imageBytes);
      final mimeType = _detectMimeType(imageBytes);

      final url = '$_geminiBaseUrl/gemini-3.5-flash:generateContent';

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "Extract fields from this payment receipt image. Return ONLY raw JSON with keys: customerName, amount, mobileNumber, transactionId, lastFourDigits, aadhaarNumber, bankName. If a field is not present, set it to null. No reasoning, no markdown, no explanation."},
              {
                "inline_data": {
                  "mime_type": mimeType,
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.1,
          "maxOutputTokens": 1024
        }
      });

      final resp = await _httpClient.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: body,
      );

      if (resp.statusCode == 429) {
        debugPrint('[AI] Gemini: Rate limited (429).');
        return AiResult(fields: {}, error: 'Gemini 429 rate limited');
      }

      if (resp.statusCode != 200) {
        String errorMsg = 'Gemini request failed';
        try {
          final errBody = jsonDecode(resp.body);
          if (errBody is Map && errBody['error'] is Map) {
            errorMsg = errBody['error']['message'] ?? errorMsg;
            if ((errBody['error']['status'] as String?) == 'RESOURCE_EXHAUSTED') {
              return AiResult(fields: {}, error: 'Gemini 429 quota exhausted');
            }
          }
        } catch (_) {}
        debugPrint('[AI] Gemini failed: ${resp.statusCode} $errorMsg');
        return AiResult(fields: {}, error: 'Gemini error: $errorMsg');
      }

      onProgress?.call(AiProgressStep.parsingResponse, 'Parsing AI response...');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint('[AI] Gemini: No candidates in response');
        return AiResult(fields: {}, error: 'Gemini returned no candidates');
      }

      final content = candidates[0]['content']?['parts']?[0]?['text'] as String?;
      if (content == null || content.isEmpty) {
        debugPrint('[AI] Gemini: Empty response content');
        return AiResult(fields: {}, error: 'Gemini returned empty response');
      }

      debugPrint('[AI] Gemini raw response: $content');

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) {
        debugPrint('[AI] Gemini: No JSON found in response');
        return AiResult(fields: {}, error: 'Gemini response did not contain valid JSON');
      }

      final jsonStr = jsonMatch.group(0)!;
      debugPrint('[AI] Gemini extracted JSON: $jsonStr');

      final fields = jsonDecode(jsonStr) as Map<String, dynamic>;
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

      debugPrint('[AI] Gemini extracted fields: $result');
      if (result.isEmpty) {
        return AiResult(fields: {}, error: 'Gemini extracted no fields from the receipt', provider: 'gemini');
      }
      return AiResult(fields: result, provider: 'gemini');
    } catch (e) {
      debugPrint('[AI] Gemini error: $e');
      return AiResult(fields: {}, error: 'Gemini error: $e', provider: 'gemini');
    }
  }

  String _detectMimeType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'image/gif';
    if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'image/webp';
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'image/bmp';
    return 'image/jpeg';
  }

  Future<AiResult> _processWithSarvam(Uint8List bytes, String filePath) async {
    debugPrint('[AI] Sarvam: Starting OCR + LLM pipeline...');

    final ocrResult = await _runOcr(bytes, filePath);
    if (ocrResult.error != null) {
      debugPrint('[AI] Sarvam OCR failed: ${ocrResult.error}');
      return AiResult(fields: {}, error: ocrResult.error, provider: 'sarvam');
    }
    if (ocrResult.text.isEmpty) {
      debugPrint('[AI] Sarvam OCR returned empty text');
      return AiResult(fields: {}, error: 'OCR returned no text. The image may be unreadable.', provider: 'sarvam');
    }

    debugPrint('[AI] Sarvam OCR text length: ${ocrResult.text.length}');
    final cleanText = _cleanOcrText(ocrResult.text);
    debugPrint('[AI] Sarvam cleaned text length: ${cleanText.length}');

    return await _extractWithLLM(cleanText);
  }

  Future<_OcrResult> _runOcr(Uint8List imageBytes, String filePath) async {
    final headers = {
      'api-subscription-key': settings.apiKey,
      'Content-Type': 'application/json',
    };

    debugPrint('[AI] Sarvam Step 1: Creating OCR job...');
    final createResp = await http.post(
      Uri.parse('$_sarvamBaseUrl/doc-digitization/job/v1'),
      headers: headers,
      body: jsonEncode({
        'job_parameters': {
          'language': 'en-IN',
          'output_format': 'md',
        },
      }),
    );

    if (createResp.statusCode != 202) {
      String errorMsg = 'Create job failed';
      try {
        final errBody = jsonDecode(createResp.body);
        if (errBody is Map && errBody['error'] is Map) {
          errorMsg = errBody['error']['message'] ?? errorMsg;
        }
      } catch (_) {}
      debugPrint('[AI] Sarvam create job failed: ${createResp.statusCode} $errorMsg');
      return _OcrResult(error: 'OCR job creation failed (${createResp.statusCode}): $errorMsg');
    }

    final createData = jsonDecode(createResp.body) as Map<String, dynamic>;
    final jobId = createData['job_id'] as String;
    debugPrint('[AI] Sarvam job created: $jobId');

    final ext = filePath.split('.').last.toLowerCase();
    final supportedExts = ['jpg', 'jpeg', 'png', 'pdf', 'webp', 'gif', 'bmp', 'heic', 'heif'];
    final fileName = supportedExts.contains(ext) ? 'document.$ext' : 'document.jpg';
    debugPrint('[AI] Sarvam using filename: $fileName');

    debugPrint('[AI] Sarvam Step 2: Getting upload URLs...');
    final uploadResp = await http.post(
      Uri.parse('$_sarvamBaseUrl/doc-digitization/job/v1/upload-files'),
      headers: headers,
      body: jsonEncode({
        'job_id': jobId,
        'files': [fileName],
      }),
    );

    if (uploadResp.statusCode != 200) {
      String errorMsg = 'Get upload URLs failed';
      try {
        final errBody = jsonDecode(uploadResp.body);
        if (errBody is Map && errBody['error'] is Map) {
          errorMsg = errBody['error']['message'] ?? errorMsg;
        }
      } catch (_) {}
      debugPrint('[AI] Sarvam get upload URLs failed: ${uploadResp.statusCode} $errorMsg');
      return _OcrResult(error: 'Upload URL request failed (${uploadResp.statusCode}): $errorMsg');
    }

    final uploadData = jsonDecode(uploadResp.body) as Map<String, dynamic>;
    final uploadUrls = uploadData['upload_urls'] as Map<String, dynamic>;
    final fileUrl = uploadUrls[fileName]?['file_url'] as String?;
    if (fileUrl == null) {
      debugPrint('[AI] Sarvam no upload URL for $fileName. Keys: ${uploadUrls.keys}');
      return _OcrResult(error: 'No upload URL returned for $fileName');
    }

    debugPrint('[AI] Sarvam Step 3: Uploading file to Azure blob...');
    final putResp = await http.put(
      Uri.parse(fileUrl),
      headers: {'x-ms-blob-type': 'BlockBlob'},
      body: imageBytes,
    );

    if (putResp.statusCode != 201) {
      debugPrint('[AI] Sarvam file upload failed: ${putResp.statusCode}');
      return _OcrResult(error: 'File upload to storage failed (${putResp.statusCode})');
    }
    debugPrint('[AI] Sarvam file uploaded successfully');

    debugPrint('[AI] Sarvam Step 4: Starting OCR job...');
    final startResp = await http.post(
      Uri.parse('$_sarvamBaseUrl/doc-digitization/job/v1/$jobId/start'),
      headers: headers,
    );

    if (startResp.statusCode != 202) {
      String errorMsg = 'Start job failed';
      try {
        final errBody = jsonDecode(startResp.body);
        if (errBody is Map && errBody['error'] is Map) {
          errorMsg = errBody['error']['message'] ?? errorMsg;
        }
      } catch (_) {}
      debugPrint('[AI] Sarvam start job failed: ${startResp.statusCode} $errorMsg');
      return _OcrResult(error: 'OCR job start failed (${startResp.statusCode}): $errorMsg');
    }
    debugPrint('[AI] Sarvam job started successfully');

    debugPrint('[AI] Sarvam Step 5: Polling for job completion...');
    for (int i = 0; i < 30; i++) {
      await Future.delayed(Duration(milliseconds: i < 2 ? 500 : 1000));

      final statusResp = await http.get(
        Uri.parse('$_sarvamBaseUrl/doc-digitization/job/v1/$jobId/status'),
        headers: headers,
      );

      if (statusResp.statusCode != 200) {
        debugPrint('[AI] Sarvam status poll $i returned ${statusResp.statusCode}');
        continue;
      }

      final statusData = jsonDecode(statusResp.body) as Map<String, dynamic>;
      final jobState = statusData['job_state'] as String? ?? '';
      debugPrint('[AI] Sarvam poll $i: job_state=$jobState');

      if (jobState == 'Completed' || jobState == 'PartiallyCompleted') {
        debugPrint('[AI] Sarvam Step 6: Downloading OCR results...');
        final downloadResp = await http.post(
          Uri.parse('$_sarvamBaseUrl/doc-digitization/job/v1/$jobId/download-files'),
          headers: headers,
        );

        if (downloadResp.statusCode != 200) {
          debugPrint('[AI] Sarvam download failed: ${downloadResp.statusCode} ${downloadResp.body}');
          return _OcrResult(error: 'Download OCR results failed (${downloadResp.statusCode})');
        }

        final downloadData = jsonDecode(downloadResp.body) as Map<String, dynamic>;
        final dlUrls = downloadData['download_urls'] as Map<String, dynamic>;
        final dlUrl = dlUrls.values.first?['file_url'] as String?;
        if (dlUrl == null) {
          debugPrint('[AI] Sarvam no download URL in response');
          return _OcrResult(error: 'No download URL in response');
        }

        debugPrint('[AI] Sarvam downloading ZIP from: $dlUrl');
        final zipResp = await http.get(Uri.parse(dlUrl));
        if (zipResp.statusCode != 200) {
          debugPrint('[AI] Sarvam ZIP download failed: ${zipResp.statusCode}');
          return _OcrResult(error: 'Download OCR ZIP failed (${zipResp.statusCode})');
        }

        debugPrint('[AI] Sarvam ZIP downloaded: ${zipResp.bodyBytes.length} bytes');
        return _OcrResult(text: _extractTextFromZip(zipResp.bodyBytes));
      }

      if (jobState == 'Failed') {
        String errorMsg = 'OCR job failed';
        try {
          if (statusData['error_message'] != null && (statusData['error_message'] as String).isNotEmpty) {
            errorMsg = statusData['error_message'] as String;
          }
        } catch (_) {}
        debugPrint('[AI] Sarvam OCR job failed: $errorMsg');
        return _OcrResult(error: 'OCR processing failed: $errorMsg');
      }
    }

    debugPrint('[AI] Sarvam OCR job timed out after 30 polls');
    return _OcrResult(error: 'OCR processing timed out. Please try again.');
  }

  String _extractTextFromZip(Uint8List zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      debugPrint('[AI] Sarvam ZIP contains ${archive.length} files');
      final allText = StringBuffer();
      for (final file in archive) {
        debugPrint('[AI] Sarvam ZIP entry: ${file.name} (isFile=${file.isFile}, size=${file.content.length})');
        if (file.isFile && !file.name.endsWith('.json')) {
          final content = String.fromCharCodes(file.content);
          allText.writeln(content);
        }
      }
      final result = allText.toString().trim();
      debugPrint('[AI] Sarvam extracted text length: ${result.length}');
      return result;
    } catch (e) {
      debugPrint('[AI] Sarvam ZIP parse error: $e');
      return '';
    }
  }

  String _cleanOcrText(String ocrText) {
    final lines = ocrText.split('\n');
    final cleaned = <String>[];
    for (final line in lines) {
      if (line.contains('[IMAGE]')) continue;
      if (line.startsWith('*') && line.endsWith('*') && line.length > 20) continue;
      cleaned.add(line);
    }
    return cleaned.join('\n')
      .replaceAll(RegExp(r'!\[.*?\]\(data:image.*?\)'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  }

  Future<AiResult> _extractWithLLM(String ocrText) async {
    try {
      debugPrint('[AI] Sarvam Step 7: Sending OCR text to LLM for field extraction...');
      debugPrint('[AI] Sarvam OCR text for LLM (first 500 chars): ${ocrText.substring(0, ocrText.length > 500 ? 500 : ocrText.length)}');

      final resp = await http.post(
        Uri.parse('$_sarvamBaseUrl/v1/chat/completions'),
        headers: {
          'api-subscription-key': settings.apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'sarvam-105b',
          'messages': [
            {
              'role': 'user',
              'content': 'Extract fields from this payment receipt text. Return ONLY raw JSON with keys: customerName, amount, mobileNumber, transactionId, lastFourDigits, aadhaarNumber, bankName. If a field is not present, set it to null. No reasoning, no markdown, no explanation.\n\n$ocrText',
            },
          ],
          'max_tokens': 4000,
        }),
      );

      if (resp.statusCode != 200) {
        String errorMsg = 'LLM request failed';
        try {
          final errBody = jsonDecode(resp.body);
          if (errBody is Map && errBody['error'] is Map) {
            errorMsg = errBody['error']['message'] ?? errorMsg;
          }
        } catch (_) {}
        debugPrint('[AI] Sarvam LLM extraction failed: ${resp.statusCode} $errorMsg');
        return AiResult(fields: {}, error: 'AI field extraction failed (${resp.statusCode}): $errorMsg', provider: 'sarvam');
      }

      debugPrint('[AI] Sarvam LLM response received successfully');

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        debugPrint('[AI] Sarvam no choices in LLM response');
        return AiResult(fields: {}, error: 'AI model returned no response choices', provider: 'sarvam');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        debugPrint('[AI] Sarvam empty content in LLM response');
        return AiResult(fields: {}, error: 'AI model returned empty response', provider: 'sarvam');
      }

      debugPrint('[AI] Sarvam LLM raw response: $content');

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) {
        debugPrint('[AI] Sarvam no JSON found in LLM response');
        return AiResult(fields: {}, error: 'AI response did not contain valid JSON. Raw response: ${content.length > 200 ? content.substring(0, 200) : content}', provider: 'sarvam');
      }

      final jsonStr = jsonMatch.group(0)!;
      debugPrint('[AI] Sarvam extracted JSON: $jsonStr');

      final fields = jsonDecode(jsonStr) as Map<String, dynamic>;
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

      debugPrint('[AI] Sarvam extracted fields: $result');
      if (result.isEmpty) {
        return AiResult(fields: {}, error: 'AI extracted no fields from the receipt. The receipt format may not be recognized.', provider: 'sarvam');
      }
      return AiResult(fields: result, provider: 'sarvam');
    } catch (e) {
      debugPrint('[AI] Sarvam LLM extraction error: $e');
      return AiResult(fields: {}, error: 'AI field extraction error: $e', provider: 'sarvam');
    }
  }

  String? matchAccountId(Map<String, dynamic> fields, List<BankAccount> accounts) {
    final last4 = fields['lastFourDigits'] as String?;
    if (last4 == null || last4.isEmpty) return null;
    for (final acc in accounts) {
      if (acc.lastFourDigits == last4) return acc.id;
    }
    return null;
  }
}

class _OcrResult {
  final String text;
  final String? error;

  _OcrResult({this.text = '', this.error});
}
