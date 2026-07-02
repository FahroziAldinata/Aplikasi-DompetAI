import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../dashboard/dashboard_provider.dart';
import '../dashboard/widgets/transaction_tile.dart';
import '../../domain/entities/transaction_entity.dart';
import 'package:dompetai/presentation/widgets/theme_toggle_button.dart';

class GroupedItem {
  final String? header;
  final TransactionEntity? transaction;
  GroupedItem({this.header, this.transaction});
}

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  Map<String, List<TransactionEntity>> _groupTransactions(List<TransactionEntity> txs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<TransactionEntity>> groups = {};

    // Sort transactions by date descending
    final sortedTxs = List<TransactionEntity>.from(txs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final tx in sortedTxs) {
      final txDate = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
      String groupKey;
      if (txDate == today) {
        groupKey = "Hari Ini";
      } else if (txDate == yesterday) {
        groupKey = "Kemarin";
      } else {
        groupKey = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(tx.createdAt);
      }

      groups.putIfAbsent(groupKey, () => []).add(tx);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Semua Transaksi",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refetch by invalidating the stream provider
          ref.invalidate(allTransactionsProvider);
          await ref.read(allTransactionsProvider.future);
        },
        child: transactionsAsync.when(
          data: (txs) {
            if (txs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          "💸",
                          style: TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada transaksi",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Mulai catat transaksi Anda di menu Chat",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final groups = _groupTransactions(txs);
            final List<GroupedItem> items = [];
            groups.forEach((key, list) {
              items.add(GroupedItem(header: key));
              for (final tx in list) {
                items.add(GroupedItem(transaction: tx));
              }
            });

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item.header != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
                    child: Text(
                      item.header!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                } else {
                  final tx = item.transaction!;
                  final cardBgColor = Theme.of(context).colorScheme.surfaceContainerHigh;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    color: cardBgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: TransactionTile(transaction: tx),
                  );
                }
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text(
              "Gagal memuat transaksi: $err",
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }
}
