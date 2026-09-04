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
  String get _model => settings.model;
  static const _maxRetries = 2;
  static const _maxDimension = 640;
  static const _jpegQuality = 50;
  static final http.Client _httpClient = http.Client();
  final AiMonitorCallback? onMonitor;
  final _log = AiLogService();

  static const _prompt =
      'IMPORTANT: Reply with ONLY a raw JSON object. No text, no explanation, no markdown, no code blocks.\n\n'
      'Look at this payment receipt image and extract these fields:\n'
      '- customerName: person name visible on receipt (the one who paid or received)\n'
      '- amount: the payment amount as a plain number. Example: if you see ₹1,000, write 1000. Do NOT extract UPI IDs or Aadhaar numbers as amount.\n'
      '- mobileNumber: exactly 10 digits phone number. If you see UPI ID like "name@ybl", extract the digits part. Do NOT use Aadhaar (12 digits) or transaction ID here.\n'
      '- transactionId: the UTR number or transaction reference ID. Usually starts with T followed by digits.\n'
      '- lastFourDigits: last 4 digits of bank account. Look for "XXXX1234" or "••••1234". Do NOT use transaction ID digits.\n'
      '- aadhaarNumber: 12-digit Aadhaar number if visible\n'
      '- bankName: bank name like SBI, YES BANK, PNB etc.\n\n'
      'Set null for fields not visible.\n'
      'Example: {"customerName":"John","amount":500,"mobileNumber":null,"transactionId":"T123","lastFourDigits":"1234","aadhaarNumber":null,"bankName":"SBI"}';

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

      // Try multiple JSON extraction strategies
      String? jsonStr;

      // Strategy 1: Look for ```json...``` code block
      final codeBlockMatch = RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true).firstMatch(content);
      if (codeBlockMatch != null) {
        jsonStr = codeBlockMatch.group(1);
      }

      // Strategy 2: Look for raw JSON object
      if (jsonStr == null) {
        final jsonMatch = RegExp(r'\{[^{}]*\}', dotAll: true).firstMatch(content);
        if (jsonMatch != null) {
          jsonStr = jsonMatch.group(0);
        }
      }

      // Strategy 3: Try to extract fields from text description
      if (jsonStr == null) {
        _log.info('No JSON found, trying text extraction...');
        final extracted = _extractFromText(content);
        if (extracted.isNotEmpty) {
          _log.info('Text extraction result: $extracted');
          return AiResult(fields: extracted, provider: 'nim');
        }
        _log.error('No JSON found and text extraction failed');
        return AiResult(fields: {}, error: 'AI response did not contain valid JSON');
      }

      _log.info('Extracted JSON: $jsonStr');

      final fields = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = <String, dynamic>{};
      for (final entry in fields.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          var val = entry.value.toString();
          if (entry.key == 'amount') {
            val = val.replaceAll(RegExp(r'[₹,\s]'), '');
            // Validate: amount should be a reasonable number (not 20+ digits)
            final numVal = int.tryParse(val);
            if (numVal == null || val.length > 12 || numVal <= 0) {
              _log.warn('Invalid amount "$val" — discarding');
              continue;
            }
          } else if (entry.key == 'lastFourDigits') {
            final last4 = RegExp(r'(\d{4})$').firstMatch(val);
            if (last4 != null) val = last4.group(1)!;
          } else if (entry.key == 'mobileNumber') {
            // Strip +91, 91, 0 prefix, spaces, dashes, parentheses
            var digits = val.replaceAll(RegExp(r'[\s\-\(\)]'), '');
            if (digits.startsWith('+91')) {
              digits = digits.substring(3);
            } else if (digits.startsWith('91') && digits.length > 10) {
              digits = digits.substring(2);
            } else if (digits.startsWith('0')) {
              digits = digits.substring(1);
            }
            // Validate: must be exactly 10 digits after cleanup
            if (digits.length != 10 || !RegExp(r'^\d{10}$').hasMatch(digits)) {
              _log.warn('Invalid mobileNumber "$val" (${digits.length} digits) — discarding');
              continue;
            }
            val = digits;
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

  Map<String, dynamic> _extractFromText(String text) {
    final result = <String, dynamic>{};

    // Extract customerName: look for "Name:", "Paid to:", "Received from:", or "Customer Name:"
    final namePatterns = [
      RegExp(r'(?:customer\s*name|paid\s*to|received\s*from|name)[:\s]+([A-Z][A-Z\s]+)', caseSensitive: false),
      RegExp(r'(?:Customer Name|Paid to|Received from)[:\s]+(.+?)(?:\n|$)', caseSensitive: false),
    ];
    for (final p in namePatterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        result['customerName'] = m.group(1)!.trim();
        break;
      }
    }

    // Extract amount: ₹3,000 or "Amount: 3000"
    final amountMatch = RegExp(r'(?:₹|INR|Rs\.?|amount[:\s]+)\s*([\d,]+)', caseSensitive: false).firstMatch(text);
    if (amountMatch != null) {
      result['amount'] = amountMatch.group(1)!.replaceAll(',', '');
    }

    // Extract transactionId: T26083021000876109384 or UTR patterns
    final txnMatch = RegExp(r'(?:transaction\s*i[dD]|UTR|ref(?:erence)?)[:\s]*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(text);
    if (txnMatch != null) {
      result['transactionId'] = txnMatch.group(1)!.trim();
    }

    // Extract mobileNumber: 10-digit phone
    final phoneMatch = RegExp(r'\b(\d{10})\b').firstMatch(text);
    if (phoneMatch != null) {
      result['mobileNumber'] = phoneMatch.group(1)!;
    }

    // Extract lastFourDigits: XXXXXXX2458 or last 4 digits pattern
    final last4Match = RegExp(r'(?:XXXX|••••|\*)(\d{4})').firstMatch(text);
    if (last4Match != null) {
      result['lastFourDigits'] = last4Match.group(1)!;
    }

    // Extract bankName
    final bankMatch = RegExp(r'(?:bank|from)[:\s]+(.*?)(?:\n|$)', caseSensitive: false).firstMatch(text);
    if (bankMatch != null) {
      result['bankName'] = bankMatch.group(1)!.trim();
    }

    return result;
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
