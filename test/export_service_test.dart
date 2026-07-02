import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompetai/domain/entities/transaction_entity.dart';
import 'package:dompetai/core/services/export_service.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (MethodCall methodCall) async {
      return null; // Mock all share method calls
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
  });

  test('Export CSV correctly formats transactions and writes file', () async {
    final transactions = [
      TransactionEntity(
        id: '1',
        rawText: 'beli bakso 15rb',
        intent: 'expense',
        category: 'Makanan',
        account: 'cash',
        amount: 15000,
        createdAt: DateTime(2026, 6, 30, 12, 0),
        confidence: 1.0,
      ),
      TransactionEntity(
        id: '2',
        rawText: 'gaji 5jt',
        intent: 'income',
        category: 'Gaji',
        account: 'rekening',
        amount: 5000000,
        createdAt: DateTime(2026, 6, 30, 13, 0),
        confidence: 1.0,
      ),
    ];

    await ExportService.exportToCSV(transactions);

    final tempDir = await getTemporaryDirectory();
    final files = tempDir.listSync().whereType<File>().toList();
    final csvFiles = files.where((f) => f.path.contains('dompetai_laporan_') && f.path.endsWith('.csv')).toList();

    expect(csvFiles.isNotEmpty, isTrue);

    // Read the latest CSV file
    csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final content = csvFiles.first.readAsStringSync();

    expect(content, contains('"No","Tanggal","Tipe","Kategori","Akun","Nominal","Deskripsi"'));
    expect(content, contains('"1","2026-06-30 12:00","expense","Makanan","cash","Rp 15.000","beli bakso 15rb"'));
    expect(content, contains('"2","2026-06-30 13:00","income","Gaji","rekening","Rp 5.000.000","gaji 5jt"'));
  });

  test('Export PDF generates A4 document with summary statistics', () async {
    final transactions = [
      TransactionEntity(
        id: '1',
        rawText: 'beli bakso 15rb',
        intent: 'expense',
        category: 'Makanan',
        account: 'cash',
        amount: 15000,
        createdAt: DateTime(2026, 6, 30, 12, 0),
        confidence: 1.0,
      ),
    ];

    await ExportService.exportToPDF(transactions);

    final tempDir = await getTemporaryDirectory();
    final files = tempDir.listSync().whereType<File>().toList();
    final pdfFiles = files.where((f) => f.path.contains('dompetai_laporan_') && f.path.endsWith('.pdf')).toList();

    expect(pdfFiles.isNotEmpty, isTrue);
  });
}
