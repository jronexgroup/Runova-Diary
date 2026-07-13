import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_settings.dart';

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
      final zipBytes = _imageToZip(bytes);

      final result = await _runDocDigitization(zipBytes);
      return _extractFields(result);
    } catch (e) {
      debugPrint('Sarvam AI request failed: $e');
      return {};
    }
  }

  Uint8List _imageToZip(Uint8List imageBytes) {
    final fileName = 'document.jpg';
    final fileNameBytes = utf8.encode(fileName);
    final crc32 = _crc32(imageBytes);

    final localHeader = ByteData(30);
    int off = 0;
    localHeader.setUint32(off, 0x04034b50, Endian.little); off += 4;
    localHeader.setUint16(off, 20, Endian.little); off += 2;
    localHeader.setUint16(off, 0, Endian.little); off += 2;
    localHeader.setUint16(off, 0, Endian.little); off += 2;
    localHeader.setUint16(off, 0, Endian.little); off += 2;
    localHeader.setUint16(off, 0, Endian.little); off += 2;
    localHeader.setUint32(off, crc32, Endian.little); off += 4;
    localHeader.setUint32(off, imageBytes.length, Endian.little); off += 4;
    localHeader.setUint32(off, imageBytes.length, Endian.little); off += 4;
    localHeader.setUint16(off, fileNameBytes.length, Endian.little); off += 2;
    localHeader.setUint16(off, 0, Endian.little);

    final centralDir = ByteData(46);
    int cdOff = 0;
    centralDir.setUint32(cdOff, 0x02014b50, Endian.little); cdOff += 4;
    centralDir.setUint16(cdOff, 20, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 20, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 0, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 0, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 0, Endian.little); cdOff += 2;
    centralDir.setUint32(cdOff, crc32, Endian.little); cdOff += 4;
    centralDir.setUint32(cdOff, imageBytes.length, Endian.little); cdOff += 4;
    centralDir.setUint32(cdOff, imageBytes.length, Endian.little); cdOff += 4;
    centralDir.setUint16(cdOff, fileNameBytes.length, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 0, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 0, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 0, Endian.little); cdOff += 2;
    centralDir.setUint16(cdOff, 0, Endian.little); cdOff += 2;
    centralDir.setUint32(cdOff, 0, Endian.little); cdOff += 4;
    centralDir.setUint32(cdOff, 0, Endian.little);

    final eocd = ByteData(22);
    int eo = 0;
    eocd.setUint32(eo, 0x06054b50, Endian.little); eo += 4;
    eocd.setUint16(eo, 0, Endian.little); eo += 2;
    eocd.setUint16(eo, 0, Endian.little); eo += 2;
    eocd.setUint16(eo, 1, Endian.little); eo += 2;
    eocd.setUint16(eo, 1, Endian.little); eo += 2;
    final cdSize = 46;
    final cdOffset = 30 + fileNameBytes.length + imageBytes.length;
    eocd.setUint32(eo, cdSize, Endian.little); eo += 4;
    eocd.setUint32(eo, cdOffset, Endian.little); eo += 4;
    eocd.setUint16(eo, 0, Endian.little);

    final result = BytesBuilder();
    result.add(localHeader.buffer.asUint8List());
    result.add(fileNameBytes);
    result.add(imageBytes);
    result.add(centralDir.buffer.asUint8List());
    result.add(fileNameBytes);
    result.add(eocd.buffer.asUint8List());
    return result.toBytes();
  }

  int _crc32(Uint8List data) {
    int crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  Future<Map<String, dynamic>> _runDocDigitization(Uint8List pdfBytes) async {
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
      return {};
    }

    final createData = jsonDecode(createResp.body) as Map<String, dynamic>;
    final jobId = createData['job_id'] as String;

    final uploadResp = await http.post(
      Uri.parse('$_baseUrl/doc-digitization/job/v1/upload-files'),
      headers: headers,
      body: jsonEncode({
        'job_id': jobId,
        'files': ['document.zip'],
      }),
    );

    if (uploadResp.statusCode != 200) {
      debugPrint('Get upload URLs failed: ${uploadResp.statusCode} ${uploadResp.body}');
      return {};
    }

    final uploadData = jsonDecode(uploadResp.body) as Map<String, dynamic>;
    final uploadUrls = uploadData['upload_urls'] as Map<String, dynamic>;
    final fileUrl = uploadUrls['document.zip']?['file_url'] as String?;
    if (fileUrl == null) {
      debugPrint('No upload URL returned');
      return {};
    }

    final putResp = await http.put(
      Uri.parse(fileUrl),
      headers: {'x-ms-blob-type': 'BlockBlob'},
      body: pdfBytes,
    );

    if (putResp.statusCode != 201) {
      debugPrint('File upload failed: ${putResp.statusCode}');
      return {};
    }

    final startResp = await http.post(
      Uri.parse('$_baseUrl/doc-digitization/job/v1/$jobId/start'),
      headers: headers,
    );

    if (startResp.statusCode != 202) {
      debugPrint('Start job failed: ${startResp.statusCode} ${startResp.body}');
      return {};
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
          return {};
        }

        final downloadData = jsonDecode(downloadResp.body) as Map<String, dynamic>;
        final dlUrls = downloadData['download_urls'] as Map<String, dynamic>;
        final dlUrl = dlUrls.values.first?['file_url'] as String?;
        if (dlUrl == null) return {};

        final zipResp = await http.get(Uri.parse(dlUrl));
        if (zipResp.statusCode != 200) return {};

        final zipBytes = zipResp.bodyBytes;
        return _parseZipOutput(zipBytes);
      }

      if (jobState == 'Failed') {
        debugPrint('Job failed');
        return {};
      }
    }

    debugPrint('Job timed out');
    return {};
  }

  Map<String, dynamic> _parseZipOutput(Uint8List zipBytes) {
    final extracted = <String, dynamic>{};
    if (zipBytes.length < 30) return extracted;

    try {
      int pos = 0;
      final allText = StringBuffer();
      String? jsonContent;

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
            if (name.endsWith('.json')) {
              jsonContent = content;
            } else {
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

      if (jsonContent != null) {
        try {
          final jsonData = jsonDecode(jsonContent) as Map<String, dynamic>;
          extracted.addAll(jsonData);
          final pages = jsonData['pages'] as List?;
          if (pages != null && pages.isNotEmpty) {
            final pageTexts = <String>[];
            for (final page in pages) {
              if (page is Map<String, dynamic>) {
                final text = page['text'] as String? ?? page['markdown'] as String? ?? '';
                if (text.isNotEmpty) pageTexts.add(text);
              }
            }
            if (pageTexts.isNotEmpty) {
              extracted['text'] = pageTexts.join('\n');
            }
          }
        } catch (_) {}
      }

      if (extracted['text'] == null) {
        final text = allText.toString();
        if (text.isNotEmpty) extracted['text'] = text;
      }
    } catch (e) {
      debugPrint('ZIP parse error: $e');
    }

    return extracted;
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
          if (val.isNotEmpty && val.length < 100) fields['customerName'] = val;
        }

        if (fields['amount'] == null) {
          final amtMatch = RegExp(r'(?:amount|amt|rs\.?|₹|total)\s*:?\s*([\d,]+\.?\d*)', caseSensitive: false)
              .firstMatch(lower);
          if (amtMatch != null) {
            final raw = amtMatch.group(1)!.replaceAll(',', '');
            final val = double.tryParse(raw);
            if (val != null && val > 0 && val < 99999999) {
              fields['amount'] = raw;
            }
          }
        }

        if (fields['mobileNumber'] == null) {
          final mobileMatch = RegExp(r'\b[6-9]\d{9}\b').firstMatch(line);
          if (mobileMatch != null) {
            fields['mobileNumber'] = mobileMatch.group(0);
          }
        }

        if (fields['transactionId'] == null) {
          final txnMatch = RegExp(
            r'(?:txn\s*id|transaction\s*(?:id|no|number)|ref\s*(?:id|no|number)|utr)\s*:?\s*([A-Za-z0-9]{6,})',
            caseSensitive: false,
          ).firstMatch(line);
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
