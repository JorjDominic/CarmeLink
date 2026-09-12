import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/receipt_ocr_service.dart';

void main() {
  const ocrService = ReceiptOcrService();

  group('ReceiptOcrService text parsing', () {
    test('extracts GCash Express Send receipt correctly', () {
      const gcashReceiptText = '''
        GCash
        Express Send
        Successfully sent to
        CARMELITA DORMITORY
        0917 123 4567
        Amount: PHP 4,500.00
        Ref No. 0024 8192 4819
        Sep 11, 2026 10:30 AM
      ''';

      final result = ocrService.parseReceiptText(gcashReceiptText);

      expect(result.paymentMethod, equals('GCash'));
      expect(result.amount, equals(4500.0));
      expect(result.referenceNumber, equals('0024 8192 4819'));
      expect(result.hasMatches, isTrue);
    });

    test('extracts GCash with multiline Ref No and peso symbol', () {
      const gcashText = '''
        Express Send
        Total Amount: ₱2,350.50
        Ref No.
        1002 9384 1029
        Completed
      ''';

      final result = ocrService.parseReceiptText(gcashText);

      expect(result.paymentMethod, equals('GCash'));
      expect(result.amount, equals(2350.50));
      expect(result.referenceNumber, equals('1002 9384 1029'));
    });

    test('extracts Maya receipt correctly', () {
      const mayaText = '''
        Maya
        Transfer Successful
        Sent to: Carmelita Management
        Amount: PHP 1,800.00
        Reference ID: 9482710384
        Date: 2026-09-11
      ''';

      final result = ocrService.parseReceiptText(mayaText);

      expect(result.paymentMethod, equals('Maya'));
      expect(result.amount, equals(1800.0));
      expect(result.referenceNumber, equals('9482710384'));
    });

    test('extracts BPI / InstaPay transfer correctly', () {
      const bpiText = '''
        BPI Online
        InstaPay Transfer Completed
        Amount PHP 5,200.00
        InstaPay Ref No. BPI93821049281
        Service Fee PHP 0.00
      ''';

      final result = ocrService.parseReceiptText(bpiText);

      expect(result.paymentMethod, equals('Bank transfer'));
      expect(result.amount, equals(5200.0));
      expect(result.referenceNumber, equals('BPI93821049281'));
    });

    test('ignores phone numbers and dates as reference numbers', () {
      const receiptWithPhoneAndDate = '''
        GCash
        Sent to 0917 888 9999
        Date: 2026-09-11
        Amount: ₱750.00
        Ref No. 9021 3456 7890
      ''';

      final result = ocrService.parseReceiptText(receiptWithPhoneAndDate);

      expect(result.amount, equals(750.0));
      expect(result.referenceNumber, equals('9021 3456 7890'));
      expect(result.referenceNumber, isNot(equals('0917 888 9999')));
      expect(result.referenceNumber, isNot(equals('2026-09-11')));
    });

    test('extracts GCash with Total Amount Sent and P prefix', () {
      const gcashTotalSentText = '''
        Express Send
        Sent to
        JUAN DELA CRUZ
        0917 123 4567
        Total Amount Sent PHP 1,500.00
        Ref No. 0024 1234 5678
      ''';

      final result = ocrService.parseReceiptText(gcashTotalSentText);

      expect(result.paymentMethod, equals('GCash'));
      expect(result.amount, equals(1500.0));
      expect(result.referenceNumber, equals('0024 1234 5678'));
    });

    test('extracts amount when peso symbol is recognized as P or F', () {
      const pText = '''
        GCash
        P 1,500.00
        Ref No. 0024 1234 5678
      ''';

      final resultP = ocrService.parseReceiptText(pText);
      expect(resultP.amount, equals(1500.0));

      const pNoSpace = '''
        GCash
        P500.00
        Ref No. 0024 1234 5678
      ''';

      final resultNoSpace = ocrService.parseReceiptText(pNoSpace);
      expect(resultNoSpace.amount, equals(500.0));
    });

    test('extracts amount under 1000 without commas and without symbols', () {
      const rawText = '''
        Express Send
        500.00
        Sent to CARMELITA
        Ref No. 1002 9384 1029
      ''';

      final result = ocrService.parseReceiptText(rawText);
      expect(result.amount, equals(500.0));
      expect(result.referenceNumber, equals('1002 9384 1029'));
    });

    test('extracts multiline Total Amount Sent and ignores convenience fee',
        () {
      const receiptWithFee = '''
        GCash
        Express Send
        Total Amount Sent
        PHP 2,500.00
        Convenience Fee: PHP 15.00
        Ref No. 0024 9999 8888
      ''';

      final result = ocrService.parseReceiptText(receiptWithFee);
      expect(result.amount, equals(2500.0));
      expect(result.referenceNumber, equals('0024 9999 8888'));
    });

    test('extracts Amount (PHP) pattern from bank/card slips', () {
      const bankText = '''
        BDO Unibank
        Transfer Successful
        Amount (PHP): 3,450.00
        Trace No. 94827103
      ''';

      final result = ocrService.parseReceiptText(bankText);
      expect(result.paymentMethod, equals('Bank transfer'));
      expect(result.amount, equals(3450.0));
      expect(result.referenceNumber, equals('94827103'));
    });

    test(
        'extracts amount when placed to the right of reference number on same line',
        () {
      const receiptText = '''
        GCash
        Express Send
        Ref No. 100 293 841 1,500.00
      ''';

      final result = ocrService.parseReceiptText(receiptText);
      expect(result.paymentMethod, equals('GCash'));
      expect(result.referenceNumber, equals('100 293 841'));
      expect(result.amount, equals(1500.0));
    });

    test(
        'extracts amount when PHP currency is to the right of reference number',
        () {
      const receiptText = '''
        GCash
        Ref No. 1002 9384 1029 PHP 2,400.00
      ''';

      final result = ocrService.parseReceiptText(receiptText);
      expect(result.referenceNumber, equals('1002 9384 1029'));
      expect(result.amount, equals(2400.0));
    });

    test(
        'extracts amount under 1000 to the right of ref without picking ref digits',
        () {
      const receiptText = '''
        Ref: 9021345678 500.00
      ''';

      final result = ocrService.parseReceiptText(receiptText);
      expect(result.referenceNumber, equals('9021345678'));
      expect(result.amount, equals(500.0));
    });

    test('handles empty or unrecognized text gracefully', () {
      final result = ocrService.parseReceiptText('   \n  ');

      expect(result.amount, isNull);
      expect(result.referenceNumber, isNull);
      expect(result.paymentMethod, isNull);
      expect(result.hasMatches, isFalse);
    });
  });
}
