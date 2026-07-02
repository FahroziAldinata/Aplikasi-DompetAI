import 'package:flutter_test/flutter_test.dart';
import 'package:dompetai/data/ai/ner_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NERParser Multi-Transaction Detection and Splitting Tests (No TFLite DLL required)', () {
    late NERParser parser;

    setUp(() {
      parser = NERParser();
    });

    test('isMultiTransaction detection logic', () {
      // Test cases that should trigger multi-transaction detection
      expect(parser.isMultiTransaction("beli jus jeruk 10 ribu, bayar parkir 2k"), isTrue);
      expect(parser.isMultiTransaction("gaji 5000000 dan bonus 1000000"), isTrue);
      expect(parser.isMultiTransaction("beli kopi 15k terus makan siang 30k"), isTrue);
      expect(parser.isMultiTransaction("bayar bensin lalu beli roti"), isTrue);
      
      // Test cases that should NOT trigger multi-transaction detection (single transactions)
      expect(parser.isMultiTransaction("beli bakso 1000"), isFalse);
      expect(parser.isMultiTransaction("beli kopi 25000"), isFalse);
      expect(parser.isMultiTransaction("gaji 5000000"), isFalse);
      expect(parser.isMultiTransaction("bayar listrik 300000"), isFalse);
      expect(parser.isMultiTransaction("transfer teman 100000"), isFalse);
    });

    test('splitMultiTransaction splitting logic', () {
      final parts1 = parser.splitMultiTransaction("beli jus jeruk 10 ribu, bayar parkir 2k");
      expect(parts1, equals(["beli jus jeruk 10 ribu", "bayar parkir 2k"]));

      final parts2 = parser.splitMultiTransaction("gaji 5000000 dan bonus 1000000");
      expect(parts2, equals(["gaji 5000000", "bonus 1000000"]));

      final parts3 = parser.splitMultiTransaction("beli kopi 15k terus makan siang 30k");
      expect(parts3, equals(["beli kopi 15k", "makan siang 30k"]));
    });

    test('parseAmount with various suffix and digit combinations (20+ cases)', () {
      expect(parser.parseAmount("20rb"), equals(20000));
      expect(parser.parseAmount("20 rb"), equals(20000));
      expect(parser.parseAmount("20ribu"), equals(20000));
      expect(parser.parseAmount("20 ribu"), equals(20000));
      expect(parser.parseAmount("2k"), equals(2000));
      expect(parser.parseAmount("2 k"), equals(2000));
      expect(parser.parseAmount("2.5jt"), equals(2500000));
      expect(parser.parseAmount("2.5 jt"), equals(2500000));
      expect(parser.parseAmount("2,5 juta"), equals(2500000));
      expect(parser.parseAmount("250k"), equals(250000));
      expect(parser.parseAmount("1.250.000"), equals(1250000));
      expect(parser.parseAmount("1250000"), equals(1250000));
      expect(parser.parseAmount("1,5jt"), equals(1500000));
      expect(parser.parseAmount("2m"), equals(2000000000));
      expect(parser.parseAmount("2 m"), equals(2000000000));
      expect(parser.parseAmount("2 miliar"), equals(2000000000));
      expect(parser.parseAmount("2 milyar"), equals(2000000000));
      expect(parser.parseAmount("300 ratus"), equals(30000));
      expect(parser.parseAmount("100"), equals(100));
      expect(parser.parseAmount("2.500"), equals(2500));
      expect(parser.parseAmount("2,500"), equals(2500));
      expect(parser.parseAmount("1.5"), equals(2)); // rounds 1.5 -> 2
      expect(parser.parseAmount("1,5"), equals(2)); // rounds 1.5 -> 2
    });

    test('parseAmount with quantity + amount ambiguous sentences (5 cases)', () {
      expect(parser.parseAmount("beli 2 ayam 15000"), equals(15000));
      expect(parser.parseAmount("jajan 3 mangkok bakso habis 45.000"), equals(45000));
      expect(parser.parseAmount("bayar parkir 2 mobil 10k"), equals(10000));
      expect(parser.parseAmount("terima transfer dari 5 orang total 2.5 jt"), equals(2500000));
      expect(parser.parseAmount("beli 10 kg beras seharga 150rb"), equals(150000));
    });

    test('parseAmount negative test cases for ratus (5 cases)', () {
      expect(parser.parseAmount("status pengiriman"), isNull);
      expect(parser.parseAmount("ratusan orang berkumpul"), isNull);
      expect(parser.parseAmount("seratus tahun keheningan"), isNull);
      expect(parser.parseAmount("sepatu ratusan ribu rupiah"), isNull);
      expect(parser.parseAmount("tatapan ratusan watt"), isNull);
    });
  });
}
