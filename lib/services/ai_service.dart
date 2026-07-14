import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_settings.dart';
import '../models/bank_account.dart';

class AiService {
  final AiSettings settings;
  static const _baseUrl = 'https://api.sarvam.ai';

  AiService(this.settings);

  Future<Map<String, dynamic>> processDocument(String filePath) async {
    if (!settings.enabled || settings.apiKey.isEmpty) {
      return {};
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) return {};

      final bytes = await file.readAsBytes();

      final ocrText = await _runOcr(bytes);
      if (ocrText.isEmpty) return {};

      return await _extractWithLLM(ocrText);
    } catch (e) {
      debugPrint('Sarvam AI request failed: $e');
      return {};
    }
  }

  Future<String> _runOcr(Uint8List imageBytes) async {
    final headers = {
      'api-subscription-key': settings.apiKey,
      'Content-Type': 'application/json',
    };

    final createResp = await http.post(
      Uri.parse('$_baseUrl/doc-digitization/job/v1'),
      headers: headers,
      body: jsonEncode({
        'job_parameters': {
          'language': 'en-IN',
          'output_format': 'md',
        },
      }),
    );

    if (createResp.statusCode != 202) {
      debugPrint('Create job failed: ${createResp.statusCode} ${createResp.body}');
      return '';
    }

    final createData = jsonDecode(createResp.body) as Map<String, dynamic>;
    final jobId = createData['job_id'] as String;

    final uploadResp = await http.post(
      Uri.parse('$_baseUrl/doc-digitization/job/v1/upload-files'),
      headers: headers,
      body: jsonEncode({
        'job_id': jobId,
        'files': ['document.jpg'],
      }),
    );

    if (uploadResp.statusCode != 200) {
      debugPrint('Get upload URLs failed: ${uploadResp.statusCode} ${uploadResp.body}');
      return '';
    }

    final uploadData = jsonDecode(uploadResp.body) as Map<String, dynamic>;
    final uploadUrls = uploadData['upload_urls'] as Map<String, dynamic>;
    final fileUrl = uploadUrls['document.jpg']?['file_url'] as String?;
    if (fileUrl == null) {
      debugPrint('No upload URL returned');
      return '';
    }

    final putResp = await http.put(
      Uri.parse(fileUrl),
      headers: {'x-ms-blob-type': 'BlockBlob'},
      body: imageBytes,
    );

    if (putResp.statusCode != 201) {
      debugPrint('File upload failed: ${putResp.statusCode}');
      return '';
    }

    final startResp = await http.post(
      Uri.parse('$_baseUrl/doc-digitization/job/v1/$jobId/start'),
      headers: headers,
    );

    if (startResp.statusCode != 202) {
      debugPrint('Start job failed: ${startResp.statusCode} ${startResp.body}');
      return '';
    }

    for (int i = 0; i < 30; i++) {
      await Future.delayed(Duration(seconds: i < 5 ? 2 : 5));

      final statusResp = await http.get(
        Uri.parse('$_baseUrl/doc-digitization/job/v1/$jobId/status'),
        headers: headers,
      );

      if (statusResp.statusCode != 200) continue;

      final statusData = jsonDecode(statusResp.body) as Map<String, dynamic>;
      final jobState = statusData['job_state'] as String? ?? '';

      if (jobState == 'Completed' || jobState == 'PartiallyCompleted') {
        final downloadResp = await http.post(
          Uri.parse('$_baseUrl/doc-digitization/job/v1/$jobId/download-files'),
          headers: headers,
        );

        if (downloadResp.statusCode != 200) {
          debugPrint('Download failed: ${downloadResp.statusCode}');
          return '';
        }

        final downloadData = jsonDecode(downloadResp.body) as Map<String, dynamic>;
        final dlUrls = downloadData['download_urls'] as Map<String, dynamic>;
        final dlUrl = dlUrls.values.first?['file_url'] as String?;
        if (dlUrl == null) return '';

        final zipResp = await http.get(Uri.parse(dlUrl));
        if (zipResp.statusCode != 200) return '';

        return _extractTextFromZip(zipResp.bodyBytes);
      }

      if (jobState == 'Failed') {
        debugPrint('OCR job failed');
        return '';
      }
    }

    debugPrint('OCR job timed out');
    return '';
  }

  String _extractTextFromZip(Uint8List zipBytes) {
    if (zipBytes.length < 30) return '';

    try {
      int pos = 0;
      final allText = StringBuffer();

      while (pos < zipBytes.length - 30) {
        if (zipBytes[pos] == 0x50 && zipBytes[pos + 1] == 0x4B &&
            zipBytes[pos + 2] == 0x03 && zipBytes[pos + 3] == 0x04) {
          final nameLen = (zipBytes[pos + 26] << 8) | zipBytes[pos + 27];
          final extraLen = (zipBytes[pos + 28] << 8) | zipBytes[pos + 29];
          final dataStart = pos + 30 + nameLen + extraLen;
          final compressedSize = (zipBytes[pos + 18] << 8) | zipBytes[pos + 19] |
              (zipBytes[pos + 20] << 16) | (zipBytes[pos + 21] << 24);

          final name = utf8.decode(zipBytes.sublist(pos + 30, pos + 30 + nameLen));

          if (!name.endsWith('/') && compressedSize > 0 && dataStart + compressedSize <= zipBytes.length) {
            final content = utf8.decode(zipBytes.sublist(dataStart, dataStart + compressedSize));
            if (!name.endsWith('.json')) {
              allText.writeln(content);
            }
          }

          final totalExtra = (zipBytes[pos + 30 - 2] << 8) | zipBytes[pos + 30 - 1];
          pos += 30 + nameLen + extraLen + compressedSize;
          if (totalExtra > 0) pos += totalExtra;
        } else {
          pos++;
        }
      }

      return allText.toString().trim();
    } catch (e) {
      debugPrint('ZIP parse error: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>> _extractWithLLM(String ocrText) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/v1/chat/completions'),
        headers: {
          'api-subscription-key': settings.apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'sarvam-105b',
          'messages': [
            {
              'role': 'user',
              'content': 'Extract fields from this payment receipt text and return ONLY a JSON object with these keys: customerName, amount, mobileNumber, transactionId, lastFourDigits, aadhaarNumber. If a field is not present, set it to null. Do not include any other text or explanation.\n\nText:\n$ocrText',
            },
          ],
          'max_tokens': 4000,
        }),
      );

      if (resp.statusCode != 200) {
        debugPrint('LLM extraction failed: ${resp.statusCode} ${resp.body}');
        return {};
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return {};

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) return {};

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) {
        debugPrint('No JSON found in LLM response');
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
      debugPrint('LLM extraction error: $e');
      return {};
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
