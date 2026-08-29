import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/ai_settings.dart';
import '../models/bank_account.dart';
import 'ai_log_service.dart';

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
    this.provider = 'nim',
    this.keyIndex = 0,
    this.totalKeys = 0,
    this.switchReason,
  });

  String get displayLabel => 'NVIDIA NIM';
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
    this.provider = 'nim',
    this.switched = false,
    this.monitorInfo = const AiMonitorInfo(),
  });

  bool get isSuccess => fields.isNotEmpty && error == null;
  bool get isEmpty => fields.isEmpty && error == null;
}

class AiService {
  final AiSettings settings;
  static const _baseUrl = 'https://integrate.api.nvidia.com/v1';
  static const _model = 'meta/llama-3.2-11b-vision-instruct';
  static const _maxRetries = 2;
  static const _maxDimension = 640;
  static const _jpegQuality = 50;
  static final http.Client _httpClient = http.Client();
  final AiMonitorCallback? onMonitor;
  final _log = AiLogService();

  static const _prompt =
      'You are a receipt parser. Look at this payment receipt image carefully.\n'
      'Extract ALL visible fields. Be precise — do NOT guess or mix up fields.\n\n'
      'Rules:\n'
      '- customerName: The name of the person who paid or received money. '
      'Look for "Name:", "Paid to:", "Received from:", or any person name on the receipt.\n'
      '- amount: The payment amount as a plain number. Remove ₹, commas, spaces.\n'
      '- mobileNumber: Exactly 10 digits. If you see a UPI ID like "name@ybl" or "name@okaxis", '
      'extract the digits from it. This is NOT a transaction ID.\n'
      '- transactionId: The UTR number, reference number, or transaction ID. '
      'It is usually a long alphanumeric code like "T2504131018526977625641" or "618009526556".\n'
      '- lastFourDigits: Last 4 digits of the bank account or card. '
      'Do NOT use transaction ID digits. Look for "XXXX1234" or "••••1234" patterns.\n'
      '- aadhaarNumber: 12-digit Aadhaar number. If you see "XXXX XXXX 1234", return "1234" as lastFourDigits.\n'
      '- bankName: Bank name like "State Bank of India", "Punjab National Bank", "YES BANK", etc.\n\n'
      'Return ONLY raw JSON. No explanation, no markdown.\n'
      '{"customerName":null,"amount":null,"mobileNumber":null,"transactionId":null,"lastFourDigits":null,"aadhaarNumber":null,"bankName":null}';

  AiService(this.settings, {this.onMonitor});

  Future<AiResult> processDocument(String filePath, {AiProgressCallback? onProgress}) async {
    if (!settings.enabled) {
      _log.warn('AI disabled');
      return AiResult(fields: {}, error: 'AI is not configured. Enable in Settings > AI Settings.');
    }

    _log.info('processDocument: $filePath');

    try {
      onProgress?.call(AiProgressStep.readingImage, 'Reading image...');
      final file = File(filePath);
      if (!file.existsSync()) {
        _log.error('File not found: $filePath');
        return AiResult(fields: {}, error: 'File not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      _log.info('Read ${bytes.length} bytes');

      onProgress?.call(AiProgressStep.compressing, 'Compressing image...');
      final compressed = _compressImage(bytes);
      _log.info('Compressed: ${bytes.length} -> ${compressed.length} bytes');

      onProgress?.call(AiProgressStep.sendingToAi, 'Sending to NVIDIA NIM...');
      _emitMonitor();

      // Retry logic
      AiResult? lastResult;
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        if (attempt > 1) {
          _log.info('Retry attempt $_maxRetries/$_maxRetries...');
          onProgress?.call(AiProgressStep.sendingToAi, 'Retrying... ($attempt/$_maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
        }

        lastResult = await _callNvidiaNim(compressed, onProgress: onProgress);
        if (lastResult.isSuccess) {
          _log.info('Success on attempt $attempt: ${lastResult.fields.length} fields');
          return lastResult;
        }

        _log.warn('Attempt $attempt failed: ${lastResult.error}');
      }

      _log.error('All $_maxRetries attempts failed');
      return lastResult!;
    } catch (e) {
      _log.error('Exception: $e');
      return AiResult(fields: {}, error: 'AI processing error: $e');
    }
  }

  void _emitMonitor() {
    onMonitor?.call(const AiMonitorInfo());
  }

  Uint8List _compressImage(Uint8List bytes) {
    try {
      final original = img.decodeImage(bytes);
      if (original == null) return bytes;

      img.Image resized = original;
      if (original.width > _maxDimension || original.height > _maxDimension) {
        resized = img.copyResize(original,
            width: original.width > original.height ? _maxDimension : null,
            height: original.height >= original.width ? _maxDimension : null,
            interpolation: img.Interpolation.nearest);
      }

      final compressed = img.encodeJpg(resized, quality: _jpegQuality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      _log.error('Image compression failed: $e');
      return bytes;
    }
  }

  Future<AiResult> _callNvidiaNim(Uint8List imageBytes, {AiProgressCallback? onProgress}) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              },
            ],
          },
        ],
        'max_tokens': 512,
        'temperature': 0.1,
      });

      _log.info('POST $_baseUrl/chat/completions (model=$_model)');
      final stopwatch = Stopwatch()..start();
      final resp = await _httpClient
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${settings.apiKey}',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      _log.info('Response: ${resp.statusCode} in ${stopwatch.elapsedMilliseconds}ms');

      if (resp.statusCode == 429) {
        _log.warn('Rate limited (429)');
        return AiResult(fields: {}, error: 'Rate limited. Please try again shortly.');
      }

      if (resp.statusCode != 200) {
        String errorMsg = 'NVIDIA NIM request failed';
        try {
          final errBody = jsonDecode(resp.body);
          if (errBody is Map) {
            if (errBody['error'] is Map) {
              errorMsg = errBody['error']['message'] ?? errorMsg;
            } else if (errBody['detail'] != null) {
              errorMsg = errBody['detail'].toString();
            }
          }
        } catch (_) {}
        _log.error('HTTP ${resp.statusCode}: $errorMsg');
        _log.error('Response body: ${resp.body}');
        return AiResult(fields: {}, error: 'AI error ($resp.statusCode): $errorMsg');
      }

      onProgress?.call(AiProgressStep.parsingResponse, 'Parsing AI response...');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        _log.error('No choices in response');
        return AiResult(fields: {}, error: 'AI returned no response');
      }

      final content = choices[0]['message']?['content'] as String?;
      if (content == null || content.isEmpty) {
        _log.error('Empty response content');
        return AiResult(fields: {}, error: 'AI returned empty response');
      }

      _log.info('Raw response: $content');

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch == null) {
        _log.error('No JSON found in response');
        return AiResult(fields: {}, error: 'AI response did not contain valid JSON');
      }

      final jsonStr = jsonMatch.group(0)!;
      _log.info('Extracted JSON: $jsonStr');

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

      _log.info('Final fields: $result');
      if (result.isEmpty) {
        return AiResult(fields: {}, error: 'AI extracted no fields from the receipt');
      }
      return AiResult(fields: result, provider: 'nim');
    } catch (e) {
      _log.error('Exception: $e');
      return AiResult(fields: {}, error: 'AI error: $e');
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
