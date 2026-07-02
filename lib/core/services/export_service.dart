import 'dart:io';
import 'package:dompetai/domain/entities/transaction_entity.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ExportService {
  // ponytail: export as CSV so Excel/Google Sheets can open it without xlsx library overhead
  static Future<void> exportToCSV(List<TransactionEntity> transactions) async {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final List<List<String>> rows = [
      ['No', 'Tanggal', 'Tipe', 'Kategori', 'Akun', 'Nominal', 'Deskripsi'],
    ];

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final no = (i + 1).toString();
      final date = dateFormat.format(tx.createdAt);
      final intent = tx.intent;
      final category = tx.category ?? '-';
      final account = tx.account ?? '-';
      final amount = tx.amount != null ? currencyFormat.format(tx.amount) : '-';
      final desc = tx.description ?? tx.rawText;

      rows.add([no, date, intent, category, account, amount, desc]);
    }

    final csvContent = rows.map((row) {
      return row.map((val) {
        final escaped = val.replaceAll('"', '""');
        return '"$escaped"';
      }).join(',');
    }).join('\n');

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/dompetai_laporan_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvContent);

    await Share.shareXFiles([XFile(file.path)], text: 'Ekspor Laporan Transaksi DompetAI (CSV)');
  }

  // ponytail: generate styled PDF report using built-in Helvetica font to avoid assets bundle size overhead
  static Future<void> exportToPDF(List<TransactionEntity> transactions) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    int totalIncome = 0;
    int totalExpense = 0;
    for (final tx in transactions) {
      if (tx.amount != null) {
        if (tx.intent == 'income') {
          totalIncome += tx.amount!;
        } else if (tx.intent == 'expense') {
          totalExpense += tx.amount!;
        }
      }
    }
    final netBalance = totalIncome - totalExpense;

    final accentColor = PdfColor.fromHex('#131316');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Laporan Keuangan DompetAI',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accentColor),
                  ),
                  pw.Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Summary Info Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                color: PdfColors.grey50,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pemasukan', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(totalIncome),
                        style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pengeluaran', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(totalExpense),
                        style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Selisih (Net)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(netBalance),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: netBalance >= 0 ? PdfColors.blue700 : PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              'Detail Transaksi (${transactions.length})',
              style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['No', 'Tanggal', 'Tipe', 'Kategori', 'Akun', 'Nominal', 'Deskripsi'],
              data: List<List<String>>.generate(transactions.length, (index) {
                final tx = transactions[index];
                return [
                  (index + 1).toString(),
                  dateFormat.format(tx.createdAt),
                  tx.intent.toUpperCase(),
                  tx.category ?? '-',
                  tx.account ?? '-',
                  tx.amount != null ? currencyFormat.format(tx.amount) : '-',
                  tx.description ?? tx.rawText,
                ];
              }),
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
              headerDecoration: pw.BoxDecoration(color: accentColor),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 7),
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
            ),
          ];
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/dompetai_laporan_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Laporan Keuangan DompetAI (PDF)');
  }
}
