import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dashboard_provider.dart';
import '../transactions/transaction_list_screen.dart';
import '../../core/services/export_service.dart';
import '../wallet/screens/cash_detail_screen.dart';
import '../wallet/screens/account_detail_screen.dart';
import 'widgets/dashboard_header.dart';
import 'package:dompetai/presentation/widgets/profile_avatar.dart';
import 'package:dompetai/presentation/widgets/theme_toggle_button.dart';

final chartPeriodProvider = StateProvider<String>((ref) => 'Mingguan');

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Color getCategoryColor(String category, ColorScheme colorScheme) {
    switch (category.toLowerCase().trim()) {
      case 'makanan':
      case 'minuman':
      case 'kuliner':
        return colorScheme.primary; // #C0C1FF
      case 'transportasi':
      case 'ojek':
      case 'transport':
        return colorScheme.tertiary; // #FFB783
      case 'tagihan':
      case 'listrik':
      case 'pulsa':
        return colorScheme.error; // #FFB4AB
      case 'belanja':
      case 'shopping':
        return colorScheme.secondary; // #BDC2FF
      case 'hiburan':
      case 'entertainment':
        return const Color(0xFF81C995);
      default:
        return colorScheme.outlineVariant;
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

  String _getCategoryEmoji(String? category) {
    if (category == null) return '💰';
    switch (category.toLowerCase().trim()) {
      case 'makanan':
      case 'minuman':
      case 'kuliner':
        return '🍔';
      case 'transportasi':
      case 'ojek':
      case 'transport':
        return '🚗';
      case 'tagihan':
      case 'listrik':
      case 'pulsa':
        return '🔌';
      case 'belanja':
      case 'shopping':
        return '🛒';
      case 'hiburan':
      case 'entertainment':
        return '🎬';
      default:
        return '💰';
    }
  }

  Widget _buildLegendItem(String category, Color color, ColorScheme colorScheme) {
    final capitalizedCategory = category.isNotEmpty 
        ? "${category[0].toUpperCase()}${category.substring(1)}" 
        : category;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          capitalizedCategory,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final cashBalance = ref.watch(cashBalanceProvider);
    final rekeningBalance = ref.watch(rekeningBalanceProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);
    final chartSpots = ref.watch(chartDataProvider);
    final walletsAsync = ref.watch(walletAccountProvider);
    final categoryExpenseAsync = ref.watch(categoryExpenseProvider);

    final chartPeriod = ref.watch(chartPeriodProvider);
    // Sync chartPeriodProvider with existing chartFilterProvider
    ref.listen<String>(chartPeriodProvider, (prev, next) {
      ref.read(chartFilterProvider.notifier).state = next == 'Mingguan' ? 'week' : 'month';
    });

    final fallbackCash = cashBalance.value ?? 0.0;
    final fallbackRekening = rekeningBalance.value ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0.0,
        title: Text(
          'DompetAI',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ProfileAvatar(radius: 18.0),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // SECTION A: Header Sliver
            const SliverToBoxAdapter(
              child: DashboardHeader(),
            ),

            // SECTION B: Balance Overview (single glass-card per design guide)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              sliver: SliverToBoxAdapter(
                child: walletsAsync.when(
                  data: (walletList) {
                    final cashWallets = walletList.where((w) => w.wallet.type == 'CASH').toList();
                    final bankWallets = walletList.where((w) => w.wallet.type == 'REKENING').toList();
                    
                    final cashAmt = cashWallets.isNotEmpty 
                        ? cashWallets.fold<double>(0.0, (sum, w) => sum + w.balance)
                        : fallbackCash;
                    final rekeningAmt = bankWallets.isNotEmpty
                        ? bankWallets.fold<double>(0.0, (sum, w) => sum + w.balance)
                        : fallbackRekening;
                    final totalSaldo = cashAmt + rekeningAmt;

                    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1F22).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TOTAL SALDO",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFmt.format(totalSaldo),
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const CashDetailScreen()),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1B1B1E).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Cash", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? const Color(0xFFC7C4D7) : Colors.black54)),
                                        const SizedBox(height: 4),
                                        Text(
                                          currencyFmt.format(cashAmt),
                                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE4E1E6) : Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AccountDetailScreen()),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1B1B1E).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text("Rekening", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? const Color(0xFFC7C4D7) : Colors.black54)),
                                            if (bankWallets.length > 1)
                                              Icon(Icons.layers_rounded, size: 14, color: isDark ? const Color(0xFFC7C4D7) : Colors.black38),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (bankWallets.isEmpty)
                                          Text(
                                            currencyFmt.format(rekeningAmt),
                                            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE4E1E6) : Colors.black87),
                                          )
                                        else
                                          ...bankWallets.take(3).map((w) => GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => AccountDetailScreen(account: w.wallet.name)),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(w.wallet.name, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                                                  Text(
                                                    NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp ').format(w.balance),
                                                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFE4E1E6) : Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                  error: (e, s) => const SizedBox(height: 160, child: Center(child: Text("Gagal memuat saldo", style: TextStyle(color: Colors.redAccent)))),
                ),
              ),
            ),

            // --- SECTION 1: Statistik Pengeluaran ---
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Statistik Pengeluaran",
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            // Mingguan Button
                            InkWell(
                              onTap: () {
                                ref.read(chartPeriodProvider.notifier).state = 'Mingguan';
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: chartPeriod == 'Mingguan' ? Colors.white : Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white, width: 1.0),
                                ),
                                child: Text(
                                  'Mingguan',
                                  style: TextStyle(
                                    color: chartPeriod == 'Mingguan' ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Bulanan Button
                            InkWell(
                              onTap: () {
                                ref.read(chartPeriodProvider.notifier).state = 'Bulanan';
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: chartPeriod == 'Bulanan' ? Colors.white : Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white, width: 1.0),
                                ),
                                child: Text(
                                  'Bulanan',
                                  style: TextStyle(
                                    color: chartPeriod == 'Bulanan' ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: chartSpots.isEmpty
                          ? Center(
                              child: Text(
                                "Belum ada data statistik pengeluaran",
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            )
                          : LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  drawHorizontalLine: true,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 24,
                                      getTitlesWidget: (value, meta) {
                                        final isWeekly = chartPeriod == 'Mingguan';
                                        String text = '';
                                        if (isWeekly) {
                                          final weeklyLabels = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];
                                          int idx = value.toInt();
                                          if (idx >= 0 && idx < weeklyLabels.length) {
                                            text = weeklyLabels[idx];
                                          }
                                        } else {
                                          int idx = value.toInt();
                                          if (idx == 0) { text = 'W1'; }
                                          else if (idx == 9) { text = 'W2'; }
                                          else if (idx == 19) { text = 'W3'; }
                                          else if (idx == 29) { text = 'W4'; }
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6.0),
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                minX: 0,
                                maxX: (chartSpots.length - 1).toDouble(),
                                minY: 0,
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (touchedSpot) => colorScheme.surfaceContainerHigh,
                                    tooltipRoundedRadius: 12,
                                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                      return touchedSpots.map((barSpot) {
                                        final isWeekly = chartPeriod == 'Mingguan';
                                        String dayName = '';
                                        if (isWeekly) {
                                          final weeklyLabels = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];
                                          int idx = barSpot.x.toInt();
                                          if (idx >= 0 && idx < weeklyLabels.length) {
                                            dayName = weeklyLabels[idx];
                                          }
                                        } else {
                                          dayName = 'Hari ${barSpot.x.toInt() + 1}';
                                        }
                                        final val = NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(barSpot.y);
                                        return LineTooltipItem(
                                          '$dayName\n$val',
                                          TextStyle(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: chartSpots,
                                    isCurved: true,
                                    color: colorScheme.primary,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          colorScheme.primary.withValues(alpha: 0.1),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // --- SECTION 2: Kategori ---
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kategori",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    categoryExpenseAsync.when(
                      data: (catMap) {
                        final currentMonthName = DateFormat('MMMM', 'id_ID').format(DateTime.now());
                        
                        // Sort categories by value descending
                        final sortedEntries = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                        
                        final List<MapEntry<String, double>> processedEntries;
                        if (sortedEntries.length > 4) {
                          final top3 = sortedEntries.take(3).toList();
                          final restSum = sortedEntries.skip(3).fold<double>(0.0, (sum, entry) => sum + entry.value);
                          processedEntries = [...top3, MapEntry("Lainnya", restSum)];
                        } else {
                          processedEntries = sortedEntries;
                        }

                        double maxVal = 0.0;
                        catMap.forEach((k, v) {
                          if (v > maxVal) {
                            maxVal = v;
                          }
                        });
                        final percentageStr = maxVal > 0.0 ? "${(maxVal * 100).toStringAsFixed(0)}%" : "0%";
                        final centerText = "$currentMonthName\n$percentageStr";

                        return Column(
                          children: [
                            SizedBox(
                              height: 190,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      centerSpaceRadius: 42,
                                      sectionsSpace: 2,
                                      sections: processedEntries.isEmpty
                                          ? [
                                              PieChartSectionData(
                                                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                                                value: 1.0,
                                                showTitle: false,
                                                radius: 45,
                                              ),
                                            ]
                                          : processedEntries.map((entry) {
                                              final color = getCategoryColor(entry.key, colorScheme);
                                              return PieChartSectionData(
                                                color: color,
                                                value: entry.value,
                                                showTitle: false,
                                                radius: 45,
                                              );
                                            }).toList(),
                                    ),
                                  ),
                                  Text(
                                    centerText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: processedEntries.isEmpty
                                  ? [
                                      _buildLegendItem("Belum ada data", colorScheme.outlineVariant.withValues(alpha: 0.5), colorScheme),
                                    ]
                                  : processedEntries.map((entry) {
                                      final color = getCategoryColor(entry.key, colorScheme);
                                      return _buildLegendItem(entry.key, color, colorScheme);
                                    }).toList(),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 140,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, stack) => const SizedBox(
                        height: 140,
                        child: Center(child: Text("Gagal memuat kategori")),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- SECTION 3: Transaksi Terakhir ---
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Transaksi Terakhir",
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TransactionListScreen()),
                            );
                          },
                          child: Text(
                            "Lihat Semua",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    recentTransactions.when(
                      data: (txs) {
                        if (txs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                "Belum ada transaksi tercatat",
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: txs.length,
                          itemBuilder: (context, index) {
                            final tx = txs[index];
                            final isExpense = tx.intent == 'expense';
                            final color = getCategoryColor(tx.category ?? '', colorScheme);
                            final emoji = _getCategoryEmoji(tx.category);
                            final rupiahFormat = NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            );
                            final formattedAmt = rupiahFormat.format(tx.amount ?? 0).replaceAll('Rp ', '');
                            final amountText = "${isExpense ? '-' : '+'}Rp $formattedAmt";
                            final amountColor = _getNominalColor(tx.intent, tx.category);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.description ?? tx.rawText,
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${tx.category ?? 'Lainnya'} • ${DateFormat("d MMM").format(tx.createdAt)}",
                                          style: TextStyle(
                                            color: isDark ? Colors.white70 : Colors.black54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    amountText,
                                    style: TextStyle(
                                      color: amountColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Text(
                          "Gagal memuat transaksi",
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showExportBottomSheet(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Ekspor Laporan Keuangan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Bagikan atau simpan catatan riwayat transaksi Anda.",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildExportOptionCard(
                      context: context,
                      title: "Laporan PDF",
                      subtitle: "Format dokumen rapi",
                      icon: "📄",
                      isDark: isDark,
                      onTap: () async {
                        Navigator.pop(context);
                        final txs = ref.read(allTransactionsProvider).value ?? [];
                        if (txs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Tidak ada transaksi untuk diekspor")),
                          );
                          return;
                        }
                        try {
                          await ExportService.exportToPDF(txs);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Gagal mengekspor PDF: $e")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildExportOptionCard(
                      context: context,
                      title: "Dokumen Excel",
                      subtitle: "Format CSV spreadsheet",
                      icon: "📊",
                      isDark: isDark,
                      onTap: () async {
                        Navigator.pop(context);
                        final txs = ref.read(allTransactionsProvider).value ?? [];
                        if (txs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Tidak ada transaksi untuk diekspor")),
                          );
                          return;
                        }
                        try {
                          await ExportService.exportToCSV(txs);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Gagal mengekspor CSV: $e")),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
