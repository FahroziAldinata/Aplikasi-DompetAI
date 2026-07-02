import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_type.dart';
import '../../core/providers/providers.dart';
import 'package:dompetai/presentation/widgets/profile_avatar.dart';
import 'package:dompetai/presentation/widgets/theme_toggle_button.dart';

// Stream Providers as requested
final debtsProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(getDebtsUseCaseProvider)().map((list) =>
      list.where((d) => d.type == DebtType.debt && !d.isPaid).toList());
});

final piutangProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(getDebtsUseCaseProvider)().map((list) =>
      list.where((d) => d.type == DebtType.receivable && !d.isPaid).toList());
});

final totalDebtProvider = StreamProvider<double>((ref) {
  return ref.watch(getDebtsUseCaseProvider)().map((list) =>
      list.where((d) => d.type == DebtType.debt && !d.isPaid)
          .fold<double>(0.0, (sum, item) => sum + item.remainingAmount));
});

final totalPiutangProvider = StreamProvider<double>((ref) {
  return ref.watch(getDebtsUseCaseProvider)().map((list) =>
      list.where((d) => d.type == DebtType.receivable && !d.isPaid)
          .fold<double>(0.0, (sum, item) => sum + item.remainingAmount));
});

class DebtOperations {
  final Ref ref;
  DebtOperations(this.ref);

  Future<void> insert({
    required String name,
    required String type, // 'debt' or 'piutang'
    required double totalAmount,
    DateTime? dueDate,
    String? note,
  }) async {
    final addDebt = ref.read(addDebtUseCaseProvider);
    final title = note != null && note.isNotEmpty ? "$name ($note)" : name;
    final debt = Debt(
      title: title,
      totalAmount: totalAmount,
      remainingAmount: totalAmount,
      type: type == 'debt' ? DebtType.debt : DebtType.receivable,
      dueDate: dueDate,
      isPaid: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await addDebt(debt);
  }

  Future<void> payInstallment(int id, double amount) async {
    final payDebt = ref.read(payDebtUseCaseProvider);
    await payDebt(id, amount);
  }

  Future<void> markAsPaid(int id) async {
    final markDebtPaid = ref.read(markDebtPaidUseCaseProvider);
    await markDebtPaid(id);
  }

  Future<void> delete(int id) async {
    final deleteDebt = ref.read(deleteDebtUseCaseProvider);
    await deleteDebt(id);
  }
}

final debtOperationsProvider = Provider<DebtOperations>((ref) {
  return DebtOperations(ref);
});

class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  int _selectedTab = 0; // 0: Utang Saya, 1: Piutang

  String getNameOnly(String title) {
    final index = title.indexOf(' (');
    if (index != -1) {
      return title.substring(0, index);
    }
    return title;
  }

  String? getNoteOnly(String title) {
    final index = title.indexOf(' (');
    if (index != -1 && title.endsWith(')')) {
      return title.substring(index + 2, title.length - 1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsProvider);
    final piutangAsync = ref.watch(piutangProvider);
    final totalDebtAsync = ref.watch(totalDebtProvider);
    final totalPiutangAsync = ref.watch(totalPiutangProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: colorScheme.surface,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            color: colorScheme.onSurface,
            onPressed: () {
              // placeholder search click
            },
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(right: 16.0, left: 8.0),
            child: ProfileAvatar(radius: 18.0),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle text (NOT in AppBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Utang & Piutang",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  "Pantau utang dan piutang kamu",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13.0,
                  ),
                ),
              ],
            ),
          ),

          // SECTION A — Summary Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Card Utang
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1D),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: colorScheme.outlineVariant, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Utang",
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11.0,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          totalDebtAsync.when(
                            data: (val) => currencyFormat.format(val),
                            loading: () => "Rp 0",
                            error: (_, __) => "Rp 0",
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                // Card Piutang
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1D),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: colorScheme.outlineVariant, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Piutang",
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11.0,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          totalPiutangAsync.when(
                            data: (val) => currencyFormat.format(val),
                            loading: () => "Rp 0",
                            error: (_, __) => "Rp 0",
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SECTION B — Tab toggle (pill style)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Center(
                        child: Text(
                          "Utang Saya",
                          style: TextStyle(
                            color: _selectedTab == 0 ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Center(
                        child: Text(
                          "Piutang",
                          style: TextStyle(
                            color: _selectedTab == 1 ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SECTION C — List
          Expanded(
            child: _selectedTab == 0
                ? debtsAsync.when(
                    data: (list) => _buildList(context, list, currencyFormat, "Belum ada utang"),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text("Gagal: $err")),
                  )
                : piutangAsync.when(
                    data: (list) => _buildList(context, list, currencyFormat, "Belum ada piutang"),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text("Gagal: $err")),
                  ),
          ),

          // BOTTOM pinned button – Card‑style neutral button
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 88.0),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _showAddDebtSheet(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 24),
                    SizedBox(width: 8),
                    Text("+ Tambah Catatan Utang"),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Debt> list,
    NumberFormat currencyFormat,
    String emptyText,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake_outlined, size: 48.0, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16.0),
            Text(
              emptyText,
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 4.0),
            Text(
              "Tambah catatan utang di bawah",
              style: TextStyle(fontSize: 12.0, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final debt = list[index];
        final initial = debt.title.isNotEmpty ? debt.title[0].toUpperCase() : "?";

        Widget statusChip;
        if (debt.dueDate != null) {
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final due = DateTime(debt.dueDate!.year, debt.dueDate!.month, debt.dueDate!.day);
          final daysLeft = due.difference(today).inDays;

          if (daysLeft <= 3) {
            final label = daysLeft < 0 ? "${daysLeft.abs()} HARI LALU" : "$daysLeft HARI LAGI";
            statusChip = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          } else {
            statusChip = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                "AMAN",
                style: TextStyle(
                  color: colorScheme.tertiary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
        } else {
          statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              "AMAN",
              style: TextStyle(
                color: colorScheme.tertiary,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16.0),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                radius: 20.0,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(
                getNameOnly(debt.title),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: 14.0,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Sisa: ${currencyFormat.format(debt.remainingAmount)}",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12.0,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  statusChip,
                  const SizedBox(width: 8.0),
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                ],
              ),
              onTap: () => _showDebtDetailSheet(context, debt, currencyFormat),
            ),
          ),
        );
      },
    );
  }

  void _showAddDebtSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddDebtSheet(),
    );
  }

  void _showDebtDetailSheet(BuildContext context, Debt debt, NumberFormat currencyFormat) {
    final colorScheme = Theme.of(context).colorScheme;
    final deadlineStr = debt.dueDate != null
        ? DateFormat('dd MMM yyyy').format(debt.dueDate!)
        : "Tidak ada";
    final note = getNoteOnly(debt.title);
    final initial = debt.title.isNotEmpty ? debt.title[0].toUpperCase() : "?";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
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

              // CircleAvatar & Name Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 28.0,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0)),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      getNameOnly(debt.title),
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // Total & Sisa rows
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total:", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0)),
                  Text(currencyFormat.format(debt.totalAmount), style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14.0)),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Sisa:", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0)),
                  Text(currencyFormat.format(debt.remainingAmount), style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14.0)),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Jatuh tempo:", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0)),
                  Text(deadlineStr, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14.0)),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Catatan:", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0)),
                    Text(note, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14.0)),
                  ],
                ),
              ],
              const SizedBox(height: 16.0),
              const Divider(),
              const SizedBox(height: 16.0),

              // Row buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showPayInstallmentDialog(context, debt);
                      },
                      child: const Text("Bayar Sebagian", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await ref.read(debtOperationsProvider).markAsPaid(debt.id!);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                          }
                        }
                      },
                      child: const Text("Lunas", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // TextButton Hapus
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteDialog(context, debt);
                  },
                  child: Text("Hapus", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPayInstallmentDialog(BuildContext context, Debt debt) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final controller = TextEditingController();

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
            "Bayar Sebagian",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Masukkan nominal pembayaran (maks: ${formatter.format(debt.remainingAmount.round())}):",
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: "Contoh: 50.000",
                  prefixText: "Rp ",
                  prefixStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final cleanAmtStr = controller.text.replaceAll('.', '').replaceAll(',', '');
                final amt = double.tryParse(cleanAmtStr) ?? 0.0;

                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nominal pembayaran harus lebih besar dari 0")),
                  );
                  return;
                }

                try {
                  await ref.read(debtOperationsProvider).payInstallment(debt.id!, amt);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                  }
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Debt debt) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Hapus Catatan",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          content: const Text(
            "Apakah Anda yakin ingin menghapus catatan ini?",
            style: TextStyle(fontSize: 13, color: Colors.white70),
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
                try {
                  await ref.read(debtOperationsProvider).delete(debt.id!);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                  }
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

class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key});

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _formatter = NumberFormat('#,###', 'id_ID');

  String _selectedType = 'debt'; // 'debt' or 'piutang'
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      final text = _amountController.text.replaceAll('.', '').replaceAll(',', '');
      if (text.isEmpty) return;

      final number = int.tryParse(text);
      if (number == null) return;

      final formatted = _formatter.format(number);
      if (formatted != _amountController.text) {
        _amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(24.0, 12.0, 24.0, MediaQuery.of(context).viewInsets.bottom + 24.0),
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
          const SizedBox(height: 24),
          Text(
            "Tambah Utang/Piutang",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // SegmentedButton: Utang Saya | Piutang
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'debt', label: Text("Utang Saya")),
                ButtonSegment(value: 'piutang', label: Text("Piutang")),
              ],
              selected: {_selectedType},
              onSelectionChanged: (val) {
                setState(() => _selectedType = val.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Colors.white,
                selectedForegroundColor: Colors.black,
                backgroundColor: colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title field
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Nama Orang",
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: "Contoh: Budi",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nominal amount field
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Nominal",
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: "0",
              hintStyle: const TextStyle(color: Colors.white38),
              prefixText: "Rp ",
              prefixStyle: const TextStyle(color: Colors.white),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Note field (Optional)
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Catatan (Opsional)",
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: "Contoh: Beli bakso",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date Picker trigger
          InkWell(
            onTap: () => _selectDueDate(context),
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
                    _dueDate == null
                        ? "Pilih Tanggal Jatuh Tempo"
                        : "Jatuh Tempo: ${DateFormat('d MMMM yyyy').format(_dueDate!)}",
                    style: TextStyle(
                      color: _dueDate == null ? Colors.white38 : Colors.white,
                    ),
                  ),
                  const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.white70),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () async {
                final name = _titleController.text.trim();
                final cleanAmtStr = _amountController.text.replaceAll('.', '').replaceAll(',', '');
                final amt = double.tryParse(cleanAmtStr) ?? 0.0;
                final note = _noteController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nama orang tidak boleh kosong")),
                  );
                  return;
                }
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nominal harus lebih besar dari 0")),
                  );
                  return;
                }

                try {
                  await ref.read(debtOperationsProvider).insert(
                        name: name,
                        type: _selectedType,
                        totalAmount: amt,
                        dueDate: _dueDate,
                        note: note,
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menyimpan: $e")));
                  }
                }
              },
              child: const Text(
                "Simpan Catatan",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
