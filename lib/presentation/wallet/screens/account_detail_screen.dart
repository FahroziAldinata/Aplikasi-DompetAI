import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../dashboard/dashboard_provider.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/app_database.dart';
import '../../transactions/transaction_list_screen.dart';
import 'package:dompetai/presentation/widgets/profile_avatar.dart';
import 'package:dompetai/presentation/widgets/theme_toggle_button.dart';

final filterIntentProvider = StateProvider<String>((ref) => 'all');

class AccountDetailScreen extends ConsumerStatefulWidget {
  final String? account;
  const AccountDetailScreen({super.key, this.account});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  late ScrollController _scrollController;
  bool _scrolled = false;

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

  Color _getCategoryColor(String? category, ColorScheme colorScheme) {
    if (category == null) return colorScheme.outline;
    switch (category.toLowerCase().trim()) {
      case 'makanan':
      case 'minuman':
      case 'kuliner':
        return colorScheme.primary;
      case 'transportasi':
      case 'ojek':
      case 'transport':
        return colorScheme.tertiary;
      case 'tagihan':
      case 'listrik':
      case 'pulsa':
        return colorScheme.error;
      case 'belanja':
      case 'shopping':
        return colorScheme.secondary;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allTransactionsAsync = ref.watch(allTransactionsProvider);
    final accountListAsync = ref.watch(accountListProvider);
    final activeFilter = ref.watch(filterIntentProvider);
    final transactionsAsync = ref.watch(allTransactionsFilteredProvider(activeFilter));

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    double totalAssets = 0.0;
    allTransactionsAsync.whenData((txs) {
      for (final tx in txs) {
        final amt = (tx.amount ?? 0).toDouble();
        if (tx.intent == 'income') {
          totalAssets += amt;
        } else if (tx.intent == 'expense') {
          totalAssets -= amt;
        }
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // AppBar
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            forceElevated: _scrolled,
            elevation: _scrolled ? 4.0 : 0.0,
            backgroundColor: colorScheme.surfaceContainerLow,
            leading: Navigator.canPop(context) ? BackButton(color: colorScheme.onSurface) : Icon(Icons.wallet_outlined, color: colorScheme.primary),
            title: Text(
              widget.account != null ? widget.account! : "Detail Rekening",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
             actions: const [
              ThemeToggleButton(),
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: ProfileAvatar(radius: 18.0),
              ),
            ],
          ),

          // SECTION A — Total assets
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TOTAL ASET",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    currencyFormat.format(totalAssets),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.outlineVariant),
                          foregroundColor: colorScheme.onSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                        ),
                        child: const Text("+ Hubungkan Akun"),
                      ),
                      const SizedBox(width: 8.0),
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // SECTION B — Account cards (HORIZONTAL scroll)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160.0,
              child: accountListAsync.when(
                data: (accounts) {
                  final listCount = accounts.length + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: listCount,
                    itemBuilder: (context, index) {
                      if (index < accounts.length) {
                        return _buildAccountCard(context, ref, accounts[index], screenWidth, currencyFormat);
                      } else {
                        return _buildAddAccountCard(context, ref, screenWidth);
                      }
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => const Center(child: Text("Gagal memuat akun")),
              ),
            ),
          ),

          // SECTION C — Recent Transactions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
              child: Text(
                "Transaksi Terbaru",
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
            ),
          ),

          // Filter chips row
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48.0,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _buildFilterChip(context, ref, "Semua", "all"),
                  const SizedBox(width: 8.0),
                  _buildFilterChip(context, ref, "Pemasukan", "income"),
                  const SizedBox(width: 8.0),
                  _buildFilterChip(context, ref, "Pengeluaran", "expense"),
                  const SizedBox(width: 8.0),
                  _buildFilterChip(context, ref, "Transfer", "transfer"),
                ],
              ),
            ),
          ),

          // Table list
          transactionsAsync.when(
            data: (rawTxs) {
              final txs = rawTxs.where((tx) {
                final acc = (tx.account ?? '').toLowerCase().trim();
                final isNotCash = acc != 'cash' && acc != 'tunai';
                if (widget.account != null) {
                  return isNotCash && acc == widget.account!.toLowerCase().trim();
                }
                return isNotCash;
              }).toList();

              if (txs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text("Tidak ada transaksi untuk filter ini.", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                );
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column Headers
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildHeaderCell("TANGGAL", 90),
                                _buildHeaderCell("REKENING/BANK", 140),
                                _buildHeaderCell("KATEGORI", 110),
                                _buildHeaderCell("NOMINAL", 110, alignRight: true),
                              ],
                            ),
                          ),
                          // Rows
                          ...txs.map((tx) {
                            final isExpense = tx.intent == 'expense';
                            final catColor = _getCategoryColor(tx.category, colorScheme);
                            
                            final dateText = DateFormat("MMM\ndd,\nyyyy").format(tx.createdAt);
                            final timeText = DateFormat("HH:mm").format(tx.createdAt);
                            
                            final formattedAmt = currencyFormat.format(tx.amount ?? 0).replaceAll('Rp ', '');
                            final amtText = "${isExpense ? '-' : '+'}Rp $formattedAmt";
                            final amtColor = _getNominalColor(tx.intent, tx.category);

                            return Container(
                              height: 56,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Date cell
                                  Container(
                                    width: 90,
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateText,
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 10.0,
                                            height: 1.1,
                                          ),
                                        ),
                                        Text(
                                          timeText,
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 9.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Account cell
                                  Container(
                                    width: 140,
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainer,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getAccountEmoji(tx.account ?? ''),
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            tx.account ?? 'Cash',
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                              fontSize: 13.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Category cell
                                  Container(
                                    width: 110,
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          tx.category ?? 'Lainnya',
                                          style: TextStyle(
                                            color: catColor,
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Amount cell
                                  Container(
                                    width: 110,
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        amtText,
                                        style: TextStyle(
                                          color: amtColor,
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text("Gagal memuat transaksi: $err", style: TextStyle(color: colorScheme.error)),
                ),
              ),
            ),
          ),

          // "View All Transactions →" Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TransactionListScreen()),
                    );
                  },
                  child: Text(
                    "Lihat Semua Transaksi →",
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, double width, {bool alignRight = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  String _getAccountEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('cash') || lower.contains('tunai')) {
      return '💵';
    } else if (lower.contains('bca') || lower.contains('mandiri') || lower.contains('bni') || lower.contains('bri') || lower.contains('bank')) {
      return '🏦';
    } else if (lower.contains('ovo') || lower.contains('gopay') || lower.contains('dana') || lower.contains('shopeepay')) {
      return '📱';
    }
    return '💳';
  }

  Widget _buildAccountCard(BuildContext context, WidgetRef ref, String name, double screenWidth, NumberFormat currencyFormat) {
    final colorScheme = Theme.of(context).colorScheme;
    final balanceAsync = ref.watch(accountBalanceProvider(name));
    final emoji = _getAccountEmoji(name);
    final digits = (name.hashCode.abs() % 10000).toString().padLeft(4, '0');

    final capitalizedName = name.isNotEmpty ? "${name[0].toUpperCase()}${name.substring(1)}" : name;

    return balanceAsync.when(
      data: (balance) {
        return Container(
          width: screenWidth * 0.85,
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24.0),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountDetailScreen(account: name),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$capitalizedName •••• $digits",
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.0,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  "Balance",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  currencyFormat.format(balance),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        width: screenWidth * 0.85,
        margin: const EdgeInsets.only(right: 12.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildAddAccountCard(BuildContext context, WidgetRef ref, double screenWidth) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: screenWidth * 0.85,
      margin: const EdgeInsets.only(right: 12.0),
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: colorScheme.outlineVariant,
          radius: 24.0,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24.0),
          onTap: () => _showAddAccountSheet(context, ref),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 32.0),
              const SizedBox(height: 8.0),
              Text(
                "Tambah Rekening",
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, WidgetRef ref, String label, String value) {
    final activeFilter = ref.watch(filterIntentProvider);
    final isSelected = activeFilter == value;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(filterIntentProvider.notifier).state = value;
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: colorScheme.surfaceContainerHigh,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
    );
  }

  void _showAddAccountSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddAccountBottomSheet(),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double gap;
  final double dash;

  DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dash = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = Path();

    double distance = 0.0;
    for (final PathMetric metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final double len = dash;
        if (distance + len < metric.length) {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        } else {
          dashPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        }
        distance += len + gap;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dash != dash;
  }
}

class _AddAccountBottomSheet extends ConsumerStatefulWidget {
  const _AddAccountBottomSheet();

  @override
  ConsumerState<_AddAccountBottomSheet> createState() => _AddAccountBottomSheetState();
}

class _AddAccountBottomSheetState extends ConsumerState<_AddAccountBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  String _selectedPreset = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _saveAccount() async {
    final name = _nameController.text.trim();
    final nominalStr = _amountController.text.replaceAll('.', '').trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama akun tidak boleh kosong")),
      );
      return;
    }

    final parsedAmount = int.tryParse(nominalStr) ?? 0;

    try {
      final db = ref.read(appDatabaseProvider);
      final txId = DateTime.now().microsecondsSinceEpoch.toString();

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: txId,
          rawText: "Saldo awal $name",
          intent: "income",
          category: const drift.Value("pemasukan"),
          amount: drift.Value(parsedAmount),
          account: drift.Value(name.toLowerCase()),
          description: const drift.Value("Saldo awal"),
          createdAt: DateTime.now(),
          confidence: 1.0,
        ),
      );

      try {
        final walletId = 'wallet_${name.toLowerCase().replaceAll(' ', '_')}';
        await db.into(db.wallets).insert(
          WalletsCompanion.insert(
            id: walletId,
            name: name,
            type: 'REKENING',
            initialBalance: drift.Value(parsedAmount),
            createdAt: DateTime.now(),
          ),
          mode: drift.InsertMode.insertOrIgnore,
        );
      } catch (_) {}

      ref.invalidate(allTransactionsProvider);
      ref.invalidate(walletAccountProvider);
      ref.invalidate(accountListProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Akun berhasil ditambahkan")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menambahkan akun: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final presets = ["BCA", "Mandiri", "BNI", "BRI", "OVO", "GoPay", "Dana", "ShopeePay"];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28.0),
          topRight: Radius.circular(28.0),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 16.0,
        bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
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
            "Tambah Rekening",
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: presets.map((preset) {
              final isSelected = _selectedPreset == preset;
              return ChoiceChip(
                label: Text(preset, style: const TextStyle(fontSize: 12.0)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedPreset = selected ? preset : '';
                    if (selected) {
                      _nameController.text = preset;
                    }
                  });
                },
                selectedColor: Colors.white24,
                backgroundColor: colorScheme.surfaceContainerHigh,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20.0),
          TextField(
            controller: _nameController,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
            decoration: InputDecoration(
              hintText: "Nama bank / e-wallet",
              hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (val) {
              final clean = val.replaceAll('.', '');
              if (clean.isEmpty) {
                _amountController.text = '';
                return;
              }
              final parsed = int.tryParse(clean);
              if (parsed != null) {
                final formatted = NumberFormat('#,###', 'id_ID').format(parsed).replaceAll(',', '.');
                _amountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
            decoration: InputDecoration(
              labelText: "Nominal Awal",
              labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white70),
              hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : Colors.white38),
              prefixText: "Rp ",
              prefixStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: 24.0),
          SizedBox(
            width: double.infinity,
            height: 50.0,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              onPressed: _saveAccount,
              child: const Text(
                "Simpan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}