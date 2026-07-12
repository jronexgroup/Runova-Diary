import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_settings.dart';

class AiService {
  final AiSettings settings;

  AiService(this.settings);

  Future<Map<String, dynamic>> processDocument(String filePath) async {
    if (!settings.enabled || settings.apiKey.isEmpty) {
      return {};
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) return {};

      final uri = Uri.parse('https://api.sarvam.ai/v1/document/extract');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${settings.apiKey}'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint('Sarvam AI API error: ${response.statusCode} $body');
        return {};
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      return _extractFields(data);
    } catch (e) {
      debugPrint('Sarvam AI request failed: $e');
      return {};
    }
  }

  Map<String, dynamic> _extractFields(Map<String, dynamic> raw) {
    final Map<String, dynamic> fields = {};

    try {
      final text = (raw['text'] as String?) ??
          (raw['extracted_text'] as String?) ??
          (raw['ocr_text'] as String?) ??
          '';
      if (text.isEmpty) return fields;

      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      for (final line in lines) {
        final lower = line.toLowerCase();

        if (fields['customerName'] == null &&
            (lower.startsWith('name:') || lower.startsWith('customer:') || lower.startsWith('customer name:'))) {
          final val = line.split(':').skip(1).join(':').trim();
          if (val.isNotEmpty) fields['customerName'] = val;
        }

        if (fields['amount'] == null) {
          final amtMatch = RegExp(r'(?:amount|amt|rs\.?|₹|total)\s*:?\s*([\d,]+\.?\d*)', caseSensitive: false)
              .firstMatch(lower);
          if (amtMatch != null) {
            fields['amount'] = amtMatch.group(1)!.replaceAll(',', '');
          }
        }

        if (fields['mobileNumber'] == null) {
          final mobileMatch = RegExp(r'\b\d{10}\b').firstMatch(line);
          if (mobileMatch != null) {
            fields['mobileNumber'] = mobileMatch.group(0);
          }
        }

        if (fields['transactionId'] == null) {
          final txnMatch = RegExp(r'(?:txn\s*id|transaction\s*(?:id|no|number)|ref\s*(?:id|no|number))\s*:?\s*([A-Za-z0-9]+)', caseSensitive: false)
              .firstMatch(line);
          if (txnMatch != null) {
            fields['transactionId'] = txnMatch.group(1);
          }
        }

        if (fields['aadhaarNumber'] == null) {
          final aadhaarMatch = RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b').firstMatch(line);
          if (aadhaarMatch != null) {
            fields['aadhaarNumber'] = aadhaarMatch.group(0)!.replaceAll(' ', '');
          }
        }
      }
    } catch (e) {
      debugPrint('Field extraction error: $e');
    }

    return fields;
  }
}
