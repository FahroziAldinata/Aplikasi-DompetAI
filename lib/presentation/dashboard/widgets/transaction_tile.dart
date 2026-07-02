import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/transaction_entity.dart';

class TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;

  const TransactionTile({
    super.key,
    required this.transaction,
  });

  static String getCategoryEmoji(String? category) {
    if (category == null) return '📝';
    switch (category.toLowerCase()) {
      case 'belanja':
        return '🛍️';
      case 'hiburan':
        return '🎬';
      case 'kesehatan':
        return '🏥';
      case 'makanan':
        return '🍔';
      case 'pemasukan':
        return '💰';
      case 'pendidikan':
        return '📚';
      case 'tagihan':
        return '💵';
      case 'transfer':
        return '💸';
      case 'transportasi':
        return '🚗';
      case 'utang':
        return '🤝';
      default:
        return '📝';
    }
  }

  static Color getCategoryColor(String? category) {
    if (category == null) return Colors.grey;
    switch (category.toLowerCase()) {
      case 'belanja':
        return Colors.orange;
      case 'hiburan':
        return Colors.tealAccent.shade700;
      case 'kesehatan':
        return Colors.red;
      case 'makanan':
        return Colors.amber;
      case 'pemasukan':
        return Colors.green;
      case 'pendidikan':
        return Colors.blue;
      case 'tagihan':
        return Colors.blueGrey;
      case 'transfer':
        return Colors.teal;
      case 'transportasi':
        return Colors.cyan;
      case 'utang':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }


  Color _getNominalColor(String intent, String? category) {
    final intentLower = intent.toLowerCase().trim();
    final catLower = (category ?? '').toLowerCase().trim();
    if (intentLower == 'income') {
      return const Color(0xFF81C995); // Hijau
    } else if (intentLower == 'expense') {
      return const Color(0xFFFFB4AB); // Merah
    } else if (intentLower == 'transfer') {
      return Colors.lightBlueAccent; // Biru muda
    } else if (intentLower == 'debt') {
      if (catLower == 'piutang') {
        return Colors.lightBlueAccent; // Biru muda
      } else {
        return const Color(0xFFFFB4AB); // Merah
      }
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.intent == 'expense';
    final prefix = isExpense ? '-' : '+';
    final categoryEmoji = getCategoryEmoji(transaction.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final formattedAmount = '$prefix${currencyFormatter.format(transaction.amount ?? 0)}';
    final description = transaction.description ?? transaction.rawText;
    final category = transaction.category ?? 'Lainnya';

    final textStyleColor = isDark ? Colors.white : Colors.black87;
    final subStyleColor = isDark ? Colors.white38 : Colors.black38;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,   // fixed square size
        height: 40,  // fixed square size
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        child: Center(
          child: Text(
            categoryEmoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
      title: Text(
        description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: textStyleColor,
        ),
      ),
      subtitle: Text(
        category,
        style: TextStyle(
          fontSize: 12,
          color: subStyleColor,
        ),
      ),
      trailing: Text(
        formattedAmount,
        style: TextStyle(
          color: _getNominalColor(transaction.intent, transaction.category),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
