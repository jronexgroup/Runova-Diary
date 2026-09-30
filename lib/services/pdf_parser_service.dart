import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/constants.dart';

class PdfParseResult {
  final Map<String, dynamic>? fields;
  final TransactionType? suggestedType;
  final String? error;
  final bool isSuccess;

  const PdfParseResult({
    this.fields,
    this.suggestedType,
    this.error,
    required this.isSuccess,
  });
}

class _Word {
  final String text;
  final double x;
  final double y;
  _Word(this.text, this.x, this.y);
}

class PdfParserService {
  static const _relipay = 'relipay';
  static const _mobisafr = 'mobisafr';

  /// Detects brand by filename prefix (Receipt* = Relipay, TransactionSlip* = Mobisafr),
  /// falls back to content detection (WhatsApp renames files to DOC-*).
  PdfParseResult parse(String filePath) {
    final fileName = filePath.split('/').last;
    try {
      final bytes = File(filePath).readAsBytesSync();
      final doc = PdfDocument(inputBytes: bytes);
      List<_Word> words;
      String plainText;
      try {
        final lines = PdfTextExtractor(doc).extractTextLines();
        plainText = lines.map((l) => l.text).join('\n');
        words = <_Word>[];
        for (final line in lines) {
          for (final w in line.wordCollection) {
            words.add(_Word(w.text, w.bounds.left, w.bounds.top));
          }
        }
      } finally {
        doc.dispose();
      }

      final brand = _detectBrand(fileName, plainText);
      if (brand == null) {
        return const PdfParseResult(
          isSuccess: false,
          error: 'Unsupported receipt. Only Relipay and Mobisafr PDFs are supported.',
        );
      }

      final kv = brand == _relipay ? _relipayPairs(words) : _mobisafrPairs(words);
      if (kv.isEmpty) {
        return const PdfParseResult(
          isSuccess: false,
          error: 'Could not read any transaction details from this PDF.',
        );
      }

      final fields = brand == _relipay ? _mapRelipay(kv) : _mapMobisafr(kv);
      if (fields.isEmpty) {
        return const PdfParseResult(
          isSuccess: false,
          error: 'Could not read transaction details from this receipt.',
        );
      }

      return PdfParseResult(
        fields: fields,
        suggestedType: fields.remove('__type') as TransactionType?,
        isSuccess: true,
      );
    } catch (e) {
      return PdfParseResult(isSuccess: false, error: 'Failed to read PDF: $e');
    }
  }

  String? _detectBrand(String fileName, String text) {
    final lower = fileName.toLowerCase();
    if (lower.startsWith('receipt')) return _relipay;
    if (lower.startsWith('transactionslip')) return _mobisafr;
    if (text.contains('ReportType') || text.contains('Bank RRN')) return _relipay;
    if (text.contains('RR Number') || text.contains('AEPS Transaction Receipt')) {
      return _mobisafr;
    }
    return null;
  }

  /// Relipay: single column — label words at x < 200, value words at x >= 200.
  Map<String, String> _relipayPairs(List<_Word> words) {
    final rows = <double, List<_Word>>{};
    for (final w in words) {
      final key = (w.y / 4).round() * 4.0;
      rows.putIfAbsent(key, () => []).add(w);
    }

    final sortedKeys = rows.keys.toList()..sort();
    final pairs = <String, String>{};
    for (final key in sortedKeys) {
      final row = rows[key]!..sort((a, b) => a.x.compareTo(b.x));
      final label = row.where((w) => w.x < 200).map((w) => w.text).join().trim();
      final value = row.where((w) => w.x >= 200).map((w) => w.text).join().trim();
      if (label.isEmpty || value.isEmpty) continue;
      final norm = _normLabel(label);
      pairs.putIfAbsent(norm, () => value);
    }
    return pairs;
  }

  /// Mobisafr: two columns — labels at x≈82 / x≈326, values at x≈175 / x≈418.
  Map<String, String> _mobisafrPairs(List<_Word> words) {
    final rows = <double, List<_Word>>{};
    for (final w in words) {
      final key = (w.y / 5).round() * 5.0;
      rows.putIfAbsent(key, () => []).add(w);
    }

    final sortedKeys = rows.keys.toList()..sort();
    final pairs = <String, String>{};
    for (final key in sortedKeys) {
      final row = rows[key]!..sort((a, b) => a.x.compareTo(b.x));
      _addPair(pairs, row, labelMin: 40, labelMax: 170, valueMin: 170, valueMax: 320);
      _addPair(pairs, row, labelMin: 280, labelMax: 410, valueMin: 410, valueMax: 800);
    }
    return pairs;
  }

  void _addPair(
    Map<String, String> pairs,
    List<_Word> row, {
    required double labelMin,
    required double labelMax,
    required double valueMin,
    required double valueMax,
  }) {
    final label = row
        .where((w) => w.x >= labelMin && w.x < labelMax)
        .map((w) => w.text)
        .join()
        .trim();
    final value = row
        .where((w) => w.x >= valueMin && w.x < valueMax)
        .map((w) => w.text)
        .join()
        .trim();
    if (label.isEmpty || value.isEmpty) return;
    pairs.putIfAbsent(_normLabel(label), () => value);
  }

  String _normLabel(String label) =>
      label.replaceAll(':', '').replaceAll(' ', '').toLowerCase();

  Map<String, dynamic> _mapRelipay(Map<String, String> kv) {
    final fields = <String, dynamic>{};

    final reportType = kv['reporttype'];
    if (reportType != null && reportType.toUpperCase().contains('AEPS')) {
      fields['__type'] = TransactionType.aeps;
    }

    final amount = kv['amount'];
    if (amount != null) fields['amount'] = _cleanAmount(amount);

    final bank = kv['bankname'] ?? kv['remarks'];
    if (bank != null) fields['bankName'] = bank;

    final mobile = kv['customermobile'];
    if (mobile != null) {
      final v = _tenDigits(mobile);
      if (v != null) fields['mobileNumber'] = v;
    }

    final rrn = kv['bankrrn'] ?? kv['utr'];
    if (rrn != null) {
      final v = rrn.replaceAll(RegExp(r'\D'), '');
      if (v.isNotEmpty) fields['utr'] = v;
    }

    return fields;
  }

  Map<String, dynamic> _mapMobisafr(Map<String, String> kv) {
    final fields = <String, dynamic>{};

    final service = kv['service'];
    if (service != null && service.toUpperCase().contains('AEPS')) {
      fields['__type'] = TransactionType.aeps;
    }

    final amount = kv['txnamount'];
    if (amount != null) fields['amount'] = _cleanAmount(amount);

    final bank = kv['bank'];
    if (bank != null) fields['bankName'] = bank;

    final mobile = kv['mobile'];
    if (mobile != null) {
      final v = _tenDigits(mobile);
      if (v != null) fields['mobileNumber'] = v;
    }

    final rrn = kv['rrnumber'];
    if (rrn != null) {
      final v = rrn.replaceAll(RegExp(r'\D'), '');
      if (v.isNotEmpty) fields['utr'] = v;
    }

    final txnId = kv['txnid'];
    if (txnId != null) {
      final v = txnId.replaceAll(RegExp(r'\D'), '');
      if (v.isNotEmpty) fields['transactionId'] = v;
    }

    return fields;
  }

  String _cleanAmount(String raw) {
    var v = raw.replaceAll(RegExp(r'[₹,\s]'), '');
    if (v.contains('.')) {
      final d = double.tryParse(v);
      if (d != null && d == d.roundToDouble()) v = d.toInt().toString();
    }
    return v;
  }

  String? _tenDigits(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10) return d;
    if (d.length > 10) return d.substring(d.length - 10);
    return null;
  }
}
