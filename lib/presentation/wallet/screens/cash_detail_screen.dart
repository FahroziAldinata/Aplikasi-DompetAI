import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../dashboard/dashboard_provider.dart';
import '../../chat/chat_screen.dart';
import '../../../core/providers/providers.dart';
import 'package:dompetai/presentation/widgets/profile_avatar.dart';
import 'package:dompetai/presentation/widgets/theme_toggle_button.dart';

class CashDetailScreen extends ConsumerStatefulWidget {
  final String? accountName;
  const CashDetailScreen({super.key, this.accountName});

  @override
  ConsumerState<CashDetailScreen> createState() => _CashDetailScreenState();
}

class _CashDetailScreenState extends ConsumerState<CashDetailScreen> {
  late ScrollController _scrollController;
  bool _scrolled = false;
  String _filterPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      final isScrolled = _scrollController.offset > 0;
      if (isScrolled != _scrolled) {
        setState(() {
          _scrolled = isScrolled;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getCategoryEmoji(String? category) {
    if (category == null) return '📝';
    switch (category.toLowerCase().trim()) {
      case 'belanja':
      case 'shopping':
        return '🛍️';
      case 'hiburan':
      case 'entertainment':
        return '🎬';
      case 'kesehatan':
        return '🏥';
      case 'makanan':
      case 'minuman':
      case 'kuliner':
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
      case 'ojek':
      case 'transport':
        return '🚗';
      case 'utang':
        return '🤝';
      default:
        return '📝';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transactionsAsync = ref.watch(cashHistoryProvider('cash:$_filterPeriod'));
    final allTransactionsAsync = ref.watch(allTransactionsProvider).whenData((list) =>
      list.where((tx) {
        final acc = (tx.account ?? '').toLowerCase().trim();
        return acc == 'cash' || acc == 'tunai';
      }).toList()
    );
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            forceElevated: _scrolled,
            elevation: _scrolled ? 4.0 : 0.0,
            backgroundColor: colorScheme.surfaceContainerLow,
            leading: BackButton(color: colorScheme.onSurface),
            title: Text(
              "Riwayat Cash",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
             actions: [
              IconButton(
                icon: const Icon(Icons.tune_outlined),
                color: colorScheme.onSurface,
                onPressed: () => _showFilterBottomSheet(context),
              ),
              const ThemeToggleButton(),
              const Padding(
                padding: EdgeInsets.only(right: 16.0, left: 8.0),
                child: ProfileAvatar(radius: 18.0),
              ),
            ],
          ),

          allTransactionsAsync.when(
            data: (allTxs) {
              final now = DateTime.now();
              final startOf7Days = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
              final startOf14Days = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 14));

              double thisWeekExpense = 0.0;
              double lastWeekExpense = 0.0;

              for (final tx in allTxs) {
                if (tx.intent == 'expense' && tx.amount != null) {
                  if (tx.createdAt.isAfter(startOf7Days)) {
                    thisWeekExpense += tx.amount!;
                  } else if (tx.createdAt.isAfter(startOf14Days)) {
                    lastWeekExpense += tx.amount!;
                  }
                }
              }

              double percentage = 0.0;
              if (lastWeekExpense > 0) {
                percentage = ((thisWeekExpense - lastWeekExpense).abs() / lastWeekExpense) * 100;
              } else if (thisWeekExpense > 0) {
                percentage = 100.0;
              }

              final thisWeekFormatted = currencyFormat.format(thisWeekExpense);
              final lastWeekFormatted = currencyFormat.format(lastWeekExpense);
              final isWorse = thisWeekExpense > lastWeekExpense;
              final changeLabel = isWorse 
                  ? "↑ ${percentage.toStringAsFixed(0)}% vs minggu lalu ($lastWeekFormatted)"
                  : "↓ ${percentage.toStringAsFixed(0)}% vs minggu lalu ($lastWeekFormatted)";

              return SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "PENGELUARAN CASH MINGGU INI",
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        thisWeekFormatted,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 32.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Icon(
                            isWorse ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: isWorse ? colorScheme.error : colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            changeLabel,
                            style: TextStyle(
                              color: isWorse ? colorScheme.error : colorScheme.tertiary,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          transactionsAsync.when(
            data: (txs) {
              if (txs.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      "Tidak ada transaksi tunai.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);
              final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

              final Map<String, List<TransactionEntity>> grouped = {};
              final List<String> orderedHeaders = [];

              for (final tx in txs) {
                final txDateOnly = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
                final txDateKey = DateFormat('yyyy-MM-dd').format(txDateOnly);

                String groupHeader;
                if (txDateKey == todayStr) {
                  groupHeader = "HARI INI";
                } else if (txDateKey == yesterdayStr) {
                  groupHeader = "KEMARIN";
                } else {
                  groupHeader = DateFormat("MMMM d", "id_ID").format(txDateOnly).toUpperCase();
                }

                if (!grouped.containsKey(groupHeader)) {
                  grouped[groupHeader] = [];
                  orderedHeaders.add(groupHeader);
                }
                grouped[groupHeader]!.add(tx);
              }

              final List<_HistoryItem> items = [];
              for (final header in orderedHeaders) {
                items.add(_HeaderItem(header));
                final tList = grouped[header] ?? [];
                for (final tx in tList) {
                  items.add(_TransactionItem(tx));
                }
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 90.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      if (item is _HeaderItem) {
                        return _buildDateHeader(context, item.date);
                      } else if (item is _TransactionItem) {
                        return _buildTransactionTile(context, ref, item.transaction, currencyFormat);
                      }
                      return const SizedBox.shrink();
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(
                child: Text("Terjadi kesalahan: $err", style: TextStyle(color: colorScheme.error)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 1.0),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, String date) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        date,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 11.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
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

  Widget _buildTransactionTile(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity tx,
    NumberFormat currencyFormat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = tx.intent == 'expense';
    final emoji = _getCategoryEmoji(tx.category);
    final timeStr = DateFormat('HH:mm').format(tx.createdAt);
    
    final formattedAmt = currencyFormat.format(tx.amount ?? 0).replaceAll('Rp ', '');
    final amtStr = "${isExpense ? '-' : '+'}Rp $formattedAmt";

    final cardBgColor = colorScheme.surfaceContainerHigh;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        color: cardBgColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          leading: Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: colorScheme.surfaceContainer,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20.0),
              ),
            ),
          ),
          title: Text(
            tx.description ?? tx.rawText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            "${tx.category ?? 'Lainnya'} • $timeStr",
            style: TextStyle(
              fontSize: 12.0,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          trailing: Text(
            amtStr,
            style: TextStyle(
              color: _getNominalColor(tx.intent, tx.category),
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () => _showTransactionDetailSheet(context, ref, tx, currencyFormat),
        ),
      ),
    );
  }

  void _showTransactionDetailSheet(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity tx,
    NumberFormat currencyFormat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = tx.intent == 'expense';
    final emoji = _getCategoryEmoji(tx.category);
    final amtStr = (isExpense ? "- " : "+ ") + currencyFormat.format(tx.amount ?? 0);
    final dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(tx.createdAt);
    final timeStr = DateFormat('HH:mm').format(tx.createdAt);
    final intentLabel = tx.intent[0].toUpperCase() + tx.intent.substring(1);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28.0),
              topRight: Radius.circular(28.0),
            ),
            border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 32.0)),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                tx.description ?? tx.rawText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                amtStr,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? colorScheme.error : colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 24.0),

              _buildDetailRow(colorScheme, "Tipe Transaksi", intentLabel),
              _buildDetailRow(colorScheme, "Kategori", tx.category ?? "Lainnya"),
              _buildDetailRow(colorScheme, "Sumber Dana", tx.accountName ?? "Cash"),
              _buildDetailRow(colorScheme, "Tanggal", dateStr),
              _buildDetailRow(colorScheme, "Waktu", timeStr),
              const SizedBox(height: 28.0),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  onPressed: () => _deleteTransaction(context, ref, tx.id),
                  child: const Text(
                    "Hapus Transaksi",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(ColorScheme colorScheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.0)),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13.0)),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref, String id) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
      if (context.mounted) {
        Navigator.pop(context); // close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transaksi berhasil dihapus")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus: $e")),
        );
      }
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheet(
        initialPeriod: _filterPeriod,
        onApply: (newPeriod) {
          setState(() {
            _filterPeriod = newPeriod;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

abstract class _HistoryItem {}

class _HeaderItem extends _HistoryItem {
  final String date;
  _HeaderItem(this.date);
}

class _TransactionItem extends _HistoryItem {
  final TransactionEntity transaction;
  _TransactionItem(this.transaction);
}

class _FilterBottomSheet extends StatelessWidget {
  final String initialPeriod;
  final Function(String) onApply;

  const _FilterBottomSheet({
    required this.initialPeriod,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String selectedPeriod = initialPeriod;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28.0),
              topRight: Radius.circular(28.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              Text(
                "Filter Transaksi",
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20.0),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text("Semua", style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'week', label: Text("Minggu", style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'month', label: Text("Bulan", style: TextStyle(fontSize: 12))),
                  ],
                  selected: {selectedPeriod},
                  onSelectionChanged: (val) {
                    setState(() {
                      selectedPeriod = val.first;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: colorScheme.primary,
                    selectedForegroundColor: colorScheme.onPrimary,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    onApply(selectedPeriod);
                  },
                  child: const Text("Terapkan", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}