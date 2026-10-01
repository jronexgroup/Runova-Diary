import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:runova_diary/services/pdf_parser_service.dart';
import 'package:runova_diary/utils/constants.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final parser = PdfParserService();

  test('Relipay (Receipt prefix, old format)', () {
    final r = parser.parse('Receipt1790763885142.pdf');
    expect(r.isSuccess, true);
    expect(r.fields!['amount'], '3000');
    expect(r.fields!['bankName'], 'State Bank of India');
    expect(r.fields!['utr'], '627117144725');
    expect(r.fields!['mobileNumber'], isNull); // old format has no Customer Mobile
    expect(r.fields!['transactionId'], isNull);
    expect(r.suggestedType, isNull); // no ReportType in old format
  });

  test('Relipay (WhatsApp DOC name, new format)', () {
    final r = parser.parse('DOC-20260927-WA0001.pdf');
    expect(r.isSuccess, true);
    expect(r.suggestedType, TransactionType.aeps); // ReportType=AEPSCW
    expect(r.fields!['bankName'], 'Bangiya Gramin Vikash Bank');
    expect(r.fields!['amount'], '3000');
    expect(r.fields!['mobileNumber'], '9593605758');
    expect(r.fields!['utr'], '627010044018');
    expect(r.fields!['transactionId'], isNull);
  });

  test('Mobisafr (TransactionSlip prefix)', () {
    final r = parser.parse('TransactionSlip_481386311.0.pdf');
    expect(r.isSuccess, true);
    expect(r.suggestedType, TransactionType.aeps); // Service contains AEPS
    expect(r.fields!['bankName'], 'Punjab National Bank - PNB');
    expect(r.fields!['amount'], '500');
    expect(r.fields!['mobileNumber'], '9564654080');
    expect(r.fields!['utr'], '627310077591');
    expect(r.fields!['transactionId'], '481386311');
  });

  test('Relipay new layout (Txnid/Name) → AEPS Cash In', () {
    final r = parser.parse('Receipt1790841316212.pdf');
    expect(r.isSuccess, true);
    expect(r.suggestedType, TransactionType.aepsCashIn);
    expect(r.fields!['amount'], '5000');
    expect(r.fields!['customerName'], 'NURUL HASAN');
    expect(r.fields!['utr'], '574288284873');
    expect(r.fields!['transactionId'], '838076563');
    expect(r.fields!['mobileNumber'], isNull); // no Customer Mobile in new layout
    expect(r.fields!['bankName'], isNull); // bank only in old layout (Remarks)
  });

  test('Mobisafr new layout (Remarks1/Reference1) → AEPS Cash In', () {
    final r = parser.parse('TransactionSlip_481589185.0.pdf');
    expect(r.isSuccess, true);
    expect(r.suggestedType, TransactionType.aepsCashIn);
    expect(r.fields!['amount'], '100');
    expect(r.fields!['customerName'], 'Abu Huraira Sekh'); // Remarks3 = VPA name
    expect(r.fields!['mobileNumber'], '9932464347'); // Remarks2
    expect(r.fields!['utr'], '627406914415'); // Reference
    expect(r.fields!['transactionId'], '481589185');
    expect(r.fields!['bankName'], isNull); // no bank in new layout
  });

  test('unsupported file rejected', () {
    final tmp = 'test/_unsupported_tmp.pdf';
    final doc = PdfDocument();
    doc.pages.add();
    final bytes = doc.saveSync();
    doc.dispose();
    File(tmp).writeAsBytesSync(bytes);

    final r = parser.parse(tmp);
    expect(r.isSuccess, false);
    expect(r.error, contains('Unsupported'));
    File(tmp).deleteSync();
  });
}
