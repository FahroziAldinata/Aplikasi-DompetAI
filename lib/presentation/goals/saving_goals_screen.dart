import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/local/app_database.dart';
import 'goal_provider.dart';
import 'package:dompetai/presentation/widgets/profile_avatar.dart';
import 'package:dompetai/presentation/widgets/theme_toggle_button.dart';

class SavingGoalsScreen extends ConsumerWidget {
  const SavingGoalsScreen({super.key});

  String _getGoalEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains("laptop")) return "💻";
    if (lower.contains("liburan")) return "✈️";
    if (lower.contains("kamera")) return "📷";
    if (lower.contains("motor")) return "🏍️";
    if (lower.contains("rumah")) return "🏠";
    if (lower.contains("hp") || lower.contains("phone")) return "📱";
    return "🎯";
  }

  String? _getQuote(String name) {
    final lower = name.toLowerCase();
    if (lower.contains("laptop")) return "“Kerja keras bagai kuda untuk laptop baru.”";
    if (lower.contains("liburan")) return "“Pantai sudah memanggil, menabunglah!”";
    if (lower.contains("rumah")) return "“Rumahku, surgaku. Selangkah lebih dekat.”";
    if (lower.contains("motor")) return "“Satu tarikan gas menuju impian.”";
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0.0,
        leading: Icon(Icons.wallet_outlined, color: colorScheme.primary),
        title: Text(
          'DompetAI',
          style: TextStyle(
            color: colorScheme.primary,
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
      body: goalsAsync.when(
        data: (goals) {
          final activeGoals = goals.where((g) => g.currentAmount < g.targetAmount).toList();
          final completedGoals = goals.where((g) => g.currentAmount >= g.targetAmount).toList();

          // Calculate summary details
          final totalSaved = goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount);

          // Calculate monthly change percentage: (thisMonthAdded / lastMonthTotal * 100)
          final now = DateTime.now();
          final startOfThisMonth = DateTime(now.year, now.month, 1);

          double thisMonthAdded = 0.0;
          double lastMonthTotal = 0.0;

          for (final goal in goals) {
            if (goal.createdAt.isAfter(startOfThisMonth) || goal.createdAt.isAtSameMomentAs(startOfThisMonth)) {
              thisMonthAdded += goal.currentAmount;
            } else {
              lastMonthTotal += goal.currentAmount;
            }
          }

          double percentage = 0.0;
          if (lastMonthTotal > 0) {
            percentage = (thisMonthAdded / lastMonthTotal) * 100;
          }

          final showChangeRow = lastMonthTotal > 0 && percentage > 0;

          return CustomScrollView(
            slivers: [
              // SECTION A — Summary Card (transparent background)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Tabungan",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12.0,
                            ),
                          ),
                          if (showChangeRow)
                            Text(
                              "+${percentage.toStringAsFixed(1)}% bln ini",
                              style: TextStyle(
                                color: colorScheme.tertiary,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        currencyFormat.format(totalSaved),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 28.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // SECTION B — "Sedang Berjalan" Header
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Sedang Berjalan",
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Text(
                          "${activeGoals.length} AKTIF",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Active goals list
              activeGoals.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                        child: Center(
                          child: Text(
                            "Belum ada target aktif",
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.0),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final goal = activeGoals[index];
                          return _buildGoalCard(context, ref, goal, currencyFormat);
                        },
                        childCount: activeGoals.length,
                      ),
                    ),

              // SECTION C — "Sudah Tercapai" Header
              if (completedGoals.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Sudah Tercapai",
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Text(
                            "${completedGoals.length} SELESAI",
                            style: TextStyle(
                              color: colorScheme.onTertiary,
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = completedGoals[index];
                      return _buildCompletedGoalCard(context, ref, goal, currencyFormat);
                    },
                    childCount: completedGoals.length,
                  ),
                ),
              ],

              // Bottom padding to ensure list items are not covered by the bottom navigation bar
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 100.0),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text("Gagal memuat target: $err", style: TextStyle(color: colorScheme.error)),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () => _showAddGoalBottomSheet(context),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    NumberFormat currencyFormat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final percentage = (progress * 100).toStringAsFixed(0);
    final deadlineStr = DateFormat('MMMM yyyy').format(goal.deadline);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: () => _showEditProgressDialog(context, ref, goal),
          onLongPress: () => _showDeleteConfirmation(context, ref, goal),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36.0,
                      height: 36.0,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Center(
                        child: Text(
                          _getGoalEmoji(goal.name),
                          style: const TextStyle(fontSize: 20.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              fontSize: 14.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            "Target: $deadlineStr",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "$percentage%",
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: SizedBox(
                    height: 6.0,
                    child: LinearProgressIndicator(
                      value: progress,
                      color: colorScheme.primary,
                      backgroundColor: colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currencyFormat.format(goal.currentAmount),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.0,
                      ),
                    ),
                    Text(
                      currencyFormat.format(goal.targetAmount),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedGoalCard(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    NumberFormat currencyFormat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final deadlineStr = DateFormat('MMM yyyy').format(goal.deadline);
    final quote = _getQuote(goal.name);

    return Opacity(
      opacity: 0.8,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: () => _showEditProgressDialog(context, ref, goal),
          onLongPress: () => _showDeleteConfirmation(context, ref, goal),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36.0,
                      height: 36.0,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Center(
                        child: Text(
                          _getGoalEmoji(goal.name),
                          style: const TextStyle(fontSize: 20.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              fontSize: 14.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            "Tercapai: $deadlineStr",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Text(
                        "✓ Selesai",
                        style: TextStyle(
                          color: colorScheme.onTertiary,
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: SizedBox(
                    height: 6.0,
                    child: LinearProgressIndicator(
                      value: 1.0,
                      color: colorScheme.tertiary,
                      backgroundColor: colorScheme.outlineVariant,
                    ),
                  ),
                ),
                if (quote != null) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    quote,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11.0,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddGoalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddGoalBottomSheet(),
    );
  }

  void _showEditProgressDialog(BuildContext context, WidgetRef ref, Goal goal) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final formattedInitial = goal.currentAmount > 0 ? formatter.format(goal.currentAmount.round()) : '';
    final controller = TextEditingController(text: formattedInitial);

    controller.addListener(() {
      final text = controller.text.replaceAll('.', '').replaceAll(',', '');
      if (text.isEmpty) return;

      final number = int.tryParse(text);
      if (number == null) return;

      final formatted = formatter.format(number);
      if (formatted != controller.text) {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });

    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Update Progress: ${goal.name}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Masukkan jumlah terkumpul saat ini (Rp):",
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: "Contoh: 5.000.000",
                  hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : Colors.white38),
                  prefixText: "Rp ",
                  prefixStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal", style: TextStyle(color: colorScheme.outline)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final cleanAmtStr = controller.text.replaceAll('.', '').replaceAll(',', '');
                final amt = double.tryParse(cleanAmtStr) ?? 0.0;
                await ref.read(goalOperationsProvider).updateGoalAmount(goal.id, amt);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Goal goal) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Hapus Target",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          content: Text(
            "Apakah Anda yakin ingin menghapus target tabungan \"${goal.name}\"?",
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal", style: TextStyle(color: colorScheme.outline)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await ref.read(goalOperationsProvider).deleteGoal(goal.id);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );
  }
}

class AddGoalBottomSheet extends ConsumerStatefulWidget {
  const AddGoalBottomSheet({super.key});

  @override
  ConsumerState<AddGoalBottomSheet> createState() => _AddGoalBottomSheetState();
}

class _AddGoalBottomSheetState extends ConsumerState<AddGoalBottomSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _formatter = NumberFormat('#,###', 'id_ID');
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      final text = _amountController.text
          .replaceAll('.', '')
          .replaceAll(',', '');
      if (text.isEmpty) return;

      final number = int.tryParse(text);
      if (number == null) return;

      final formatted = _formatter.format(number);
      if (formatted != _amountController.text) {
        _amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(
            offset: formatted.length,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 30),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Tambah Target Baru",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
            decoration: InputDecoration(
              labelText: "Nama Target",
              labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white70),
              hintText: "Contoh: Beli Laptop Baru",
              hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : Colors.white38),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nominal amount field
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: "Target Nominal",
              labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white70),
              hintText: "0",
              hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : Colors.white38),
              prefixText: "Rp ",
              prefixStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date Picker trigger
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDate == null
                        ? "Pilih Tanggal Batas (Deadline)"
                        : "Batas: ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate!)}",
                    style: TextStyle(
                      color: _selectedDate == null
                          ? (Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)
                          : (Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
                    ),
                  ),
                  Icon(Icons.calendar_today_rounded, size: 20, color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final name = _nameController.text.trim();
                final cleanAmtStr = _amountController.text.replaceAll('.', '').replaceAll(',', '');
                final amt = double.tryParse(cleanAmtStr) ?? 0.0;
                final deadline = _selectedDate;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nama target tidak boleh kosong")),
                  );
                  return;
                }
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nominal target harus lebih besar dari 0")),
                  );
                  return;
                }
                if (deadline == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Pilih tanggal batas terlebih dahulu")),
                  );
                  return;
                }

                await ref.read(goalOperationsProvider).addGoal(
                      name: name,
                      targetAmount: amt,
                      deadline: deadline,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "Simpan Target",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
