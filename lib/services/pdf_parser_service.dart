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

      // New Mobisafr layout (Remarks1/Reference1) differs in columns AND
      // label/value y-alignment — needs proximity row pairing.
      final mobisafrNew = brand == _mobisafr &&
          (plainText.contains('Remarks1') || plainText.contains('Reference1'));

      final kv = brand == _relipay
          ? _relipayPairs(words)
          : (mobisafrNew ? _mobisafrNewPairs(words) : _mobisafrPairs(words));
      if (kv.isEmpty) {
        return const PdfParseResult(
          isSuccess: false,
          error: 'Could not read any transaction details from this PDF.',
        );
      }

      final status = kv['status'];
      if (status != null) {
        final s = status.toLowerCase();
        if (!s.contains('success') && !s.contains('settled')) {
          return PdfParseResult(
            isSuccess: false,
            error: 'Receipt status is "$status" — only successful transactions can be added.',
          );
        }
      }

      final fields = brand == _relipay
          ? _mapRelipay(kv)
          : (mobisafrNew ? _mapMobisafrNew(kv) : _mapMobisafr(kv));
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
    if (text.contains('CSP FIRM NAME')) return _relipay;
    if (text.contains('RR Number') || text.contains('AEPS Transaction Receipt')) {
      return _mobisafr;
    }
    if (text.contains('Remarks1') || text.contains('Reference1') || text.contains('MOBISAFAR')) {
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

  /// Mobisafr new layout: label/value x-offsets differ from the old layout and
  /// label/value y values are ~0.1-1.4px apart, which breaks fixed-bucket
  /// row grouping — so rows are grouped by y-proximity instead.
  Map<String, String> _mobisafrNewPairs(List<_Word> words) {
    final sorted = [...words]..sort((a, b) => a.y.compareTo(b.y));
    final rows = <List<_Word>>[];
    for (final w in sorted) {
      if (rows.isEmpty || (w.y - rows.last.first.y) > 3) {
        rows.add([w]);
      } else {
        rows.last.add(w);
      }
    }

    final pairs = <String, String>{};
    for (final row in rows) {
      row.sort((a, b) => a.x.compareTo(b.x));
      _addPair(pairs, row, labelMin: 60, labelMax: 150, valueMin: 150, valueMax: 300);
      _addPair(pairs, row, labelMin: 300, labelMax: 375, valueMin: 375, valueMax: 700);
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
    } else if (kv['txnid'] != null && kv['name'] != null) {
      // Relipay's newer receipt layout (Txnid/Name/Txndate) — AEPS Cash In.
      fields['__type'] = TransactionType.aepsCashIn;
    }

    final amount = kv['amount'];
    if (amount != null) fields['amount'] = _cleanAmount(amount);

    final bank = kv['bankname'] ?? kv['remarks'];
    if (bank != null) fields['bankName'] = bank;

    final name = kv['name'];
    if (name != null && name.trim().isNotEmpty) {
      fields['customerName'] = name.trim();
    }

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

    final txnId = kv['txnid'];
    if (txnId != null) {
      final v = txnId.replaceAll(RegExp(r'\D'), '');
      if (v.isNotEmpty) fields['transactionId'] = v;
    }

    return fields;
  }

  /// Mobisafr's newer layout (Remarks1-4 / Reference / Status rows).
  /// Customer = Remarks3 (matches VPA name), mobile = Remarks2.
  Map<String, dynamic> _mapMobisafrNew(Map<String, String> kv) {
    final fields = <String, dynamic>{};

    final service = kv['service'];
    fields['__type'] = (service != null && service.toUpperCase().contains('AEPS'))
        ? TransactionType.aeps
        : TransactionType.aepsCashIn;

    final amount = kv['amount'];
    if (amount != null) fields['amount'] = _cleanAmount(amount);

    final name = kv['remarks3'];
    if (name != null && name.trim().isNotEmpty) {
      fields['customerName'] = name.trim();
    }

    final mobile = kv['remarks2'];
    if (mobile != null) {
      final v = _tenDigits(mobile);
      if (v != null) fields['mobileNumber'] = v;
    }

    final rrn = kv['reference'];
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
