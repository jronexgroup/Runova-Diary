class TextParseResult {
  final Map<String, String?> fields;
  final String? error;
  final bool isSuccess;

  const TextParseResult({
    required this.fields,
    this.error,
    required this.isSuccess,
  });
}

class TextParserService {
  static final _bankCodes = {
    'SBIN': 'State Bank of India',
    'SBIN000': 'State Bank of India',
    'SBIN0000': 'State Bank of India',
    'PUNB': 'Punjab National Bank',
    'PUNB0': 'Punjab National Bank',
    'HDFC': 'HDFC Bank',
    'HDFC0': 'HDFC Bank',
    'ICIC': 'ICICI Bank',
    'ICIC0': 'ICICI Bank',
    'UBIN': 'Union Bank of India',
    'UBIN0': 'Union Bank of India',
    'BARB': 'Bank of Baroda',
    'BARB0': 'Bank of Baroda',
    'IDFB': 'IDFC First Bank',
    'IDFB0': 'IDFC First Bank',
    'AIRP': 'Airtel Payments Bank',
    'AIRP0': 'Airtel Payments Bank',
    'PYTM': 'Paytm Payments Bank',
    'PYTM0': 'Paytm Payments Bank',
    'YONO': 'SBI YONO',
    'KKBK': 'Kotak Mahindra Bank',
    'KKBK0': 'Kotak Mahindra Bank',
    'INDB': 'IndusInd Bank',
    'INDB0': 'IndusInd Bank',
    'BDBL': 'Bandhan Bank',
    'BDBL0': 'Bandhan Bank',
    'FDRL': 'Federal Bank',
    'FDRL0': 'Federal Bank',
    'TMBL': 'Tamilnad Mercantile Bank',
    'TMBL0': 'Tamilnad Mercantile Bank',
    'KVBL': 'Karur Vysya Bank',
    'KVBL0': 'Karur Vysya Bank',
    'CIUB': 'City Union Bank',
    'CIUB0': 'City Union Bank',
    'UCBA': 'UCO Bank',
    'UCBA0': 'UCO Bank',
    'ALLA': 'Allahabad Bank',
    'ALLA0': 'Allahabad Bank',
    'ANDB': 'Andhra Bank',
    'ANDB0': 'Andhra Bank',
    'CBIN': 'Central Bank of India',
    'CBIN0': 'Central Bank of India',
    'CORP': 'Corporation Bank',
    'CORP0': 'Corporation Bank',
    'IDIB': 'Indian Overseas Bank',
    'IDIB0': 'Indian Overseas Bank',
    'IOBA': 'Indian Overseas Bank',
    'IOBA0': 'Indian Overseas Bank',
    'MAHB': 'Bank of Maharashtra',
    'MAHB0': 'Bank of Maharashtra',
    'PJSB': 'Global Trust Bank',
    'PJSB0': 'Global Trust Bank',
    'RATN': 'RBL Bank',
    'RATN0': 'RBL Bank',
    'SIBL': 'South Indian Bank',
    'SIBL0': 'South Indian Bank',
    'SYNB': 'Syndicate Bank',
    'SYNB0': 'Syndicate Bank',
    'UCO': 'UCO Bank',
    'UBI': 'Union Bank of India',
    'YESB': 'Yes Bank',
    'YESB0': 'Yes Bank',
    'DLSC': 'Development Credit Bank',
    'DLSC0': 'Development Credit Bank',
    'JAKA': 'Jammu and Kashmir Bank',
    'JAKA0': 'Jammu and Kashmir Bank',
    'KARB': 'Karnataka Bank',
    'KARB0': 'Karnataka Bank',
    'LAVB': 'Lakshmi Vilas Bank',
    'LAVB0': 'Lakshmi Vilas Bank',
    'NESF': 'North East Small Finance Bank',
    'NESF0': 'North East Small Finance Bank',
    'PARB': 'Park Bank',
    'PARB0': 'Park Bank',
    'PSIB': 'Punjab & Sind Bank',
    'PSIB0': 'Punjab & Sind Bank',
    'RBCS': 'RBL Bank',
    'RBCS0': 'RBL Bank',
    'SGBA': 'Saurashtra Gramin Bank',
    'SGBA0': 'Saurashtra Gramin Bank',
    'TNSC': 'Tamil Nadu State Cooperative Bank',
    'TNSC0': 'Tamil Nadu State Cooperative Bank',
    'UTBI': 'United Bank of India',
    'UTBI0': 'United Bank of India',
  };

  TextParseResult parse(String text) {
    if (text.trim().isEmpty) {
      return const TextParseResult(fields: {}, error: 'Empty text', isSuccess: false);
    }

    final fields = <String, String?>{};

    final amount = _extractAmount(text);
    if (amount != null) fields['amount'] = amount;

    final txnId = _extractTransactionId(text);
    if (txnId != null) fields['transactionId'] = txnId;

    final name = _extractCustomerName(text);
    if (name != null) fields['customerName'] = name;

    final bank = _extractBankName(text);
    if (bank != null) fields['bankName'] = bank;

    final mobile = _extractMobileNumber(text);
    if (mobile != null) fields['mobileNumber'] = mobile;

    if (fields.isEmpty) {
      return const TextParseResult(fields: {}, error: 'Could not extract any fields from text', isSuccess: false);
    }

    return TextParseResult(fields: fields, isSuccess: true);
  }

  String? _extractAmount(String text) {
    final patterns = [
      RegExp(r'Amount\s*:\s*₹\s*([\d,]+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'Amount\s*:\s*([\d,]+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'₹\s*([\d,]+(?:\.\d+)?)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var amount = match.group(1)!.replaceAll(',', '');
        if (amount.contains('.')) {
          amount = double.parse(amount).toInt().toString();
        }
        if (amount.length <= 12) return amount;
      }
    }
    return null;
  }

  String? _extractTransactionId(String text) {
    final patterns = [
      RegExp(r'UPI/CR/(\d+)', caseSensitive: false),
      RegExp(r'UPI/DR/(\d+)', caseSensitive: false),
      RegExp(r'UTR\s*:?\s*(\d+)', caseSensitive: false),
      RegExp(r'(?:Ref|REF|ref|Transaction\s*ID|TXN)\s*:?\s*(\w{8,})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  String? _extractCustomerName(String text) {
    final patterns = [
      RegExp(r'UPI/CR/\d+/(\w+)', caseSensitive: false),
      RegExp(r'UPI/DR/\d+/(\w+)', caseSensitive: false),
      RegExp(r'(?:Paid to|Received from|Name|Customer|To|From)\s*:?\s*([A-Z][A-Za-z\s]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (name.length >= 2 && name.length <= 50 && !RegExp(r'^\d+$').hasMatch(name)) {
          return name.toUpperCase();
        }
      }
    }
    return null;
  }

  String? _extractBankName(String text) {
    final patterns = [
      RegExp(r'UPI/CR/\d+/\w+/(\w+)', caseSensitive: false),
      RegExp(r'UPI/DR/\d+/\w+/(\w+)', caseSensitive: false),
      RegExp(r'(?:Bank|From|To)\s*:?\s*([A-Z][A-Za-z\s&]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var code = match.group(1)!.trim();

        if (_bankCodes.containsKey(code)) {
          return _bankCodes[code];
        }

        if (code.length >= 3 && !RegExp(r'^\d+$').hasMatch(code)) {
          return code;
        }
      }
    }
    return null;
  }

  String? _extractMobileNumber(String text) {
    final patterns = [
      RegExp(r'UPI/CR/\d+/\w+/\w+/(\d+)'),
      RegExp(r'UPI/DR/\d+/\w+/\w+/(\d+)'),
      RegExp(r'(?<!\d)(\d{10})(?!\d)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var mobile = match.group(1)!;
        if (mobile.length == 10) return mobile;
      }
    }

    final allNums = RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!).toList();
    for (final num in allNums) {
      if (num.length >= 7 && num.length <= 10) {
        return num;
      }
    }

    return null;
  }
}
