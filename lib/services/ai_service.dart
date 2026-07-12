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
        ..headers['x-model'] = settings.model
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
      final text = (raw['text'] as String?) ?? (raw['extracted_text'] as String?) ?? '';
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final full = text.toLowerCase();

      if (full.contains('name:') || full.contains('customer:')) {
        for (final line in lines) {
          final lower = line.toLowerCase();
          if (lower.startsWith('name:') || lower.startsWith('customer:')) {
            fields['customerName'] = line.split(':').skip(1).join(':').trim();
            break;
          }
        }
      }

      final amountMatch = RegExp(r'(?:amount|amt|rs\.?|₹)\s*:?\s*([\d,]+\.?\d*)', caseSensitive: false).firstMatch(full);
      if (amountMatch != null) {
        fields['amount'] = amountMatch.group(1)!.replaceAll(',', '');
      }

      final mobileMatch = RegExp(r'\b\d{10}\b').firstMatch(full);
      if (mobileMatch != null) {
        fields['mobileNumber'] = mobileMatch.group(0);
      }

      final txnIdMatch = RegExp(r'(?:txn\s*id|transaction\s*(?:id|no|number)|ref\s*(?:id|no|number))\s*:?\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(full);
      if (txnIdMatch != null) {
        fields['transactionId'] = txnIdMatch.group(1);
      }

      final aadhaarMatch = RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b').firstMatch(full);
      if (aadhaarMatch != null) {
        fields['aadhaarNumber'] = aadhaarMatch.group(0)!.replaceAll(' ', '');
      }
    } catch (e) {
      debugPrint('Field extraction error: $e');
    }

    return fields;
  }
}
