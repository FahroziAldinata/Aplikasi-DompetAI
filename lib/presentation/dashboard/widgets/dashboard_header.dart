import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dompetai/domain/entities/debt.dart';
import 'package:dompetai/presentation/providers/debt_provider.dart';
import 'package:dompetai/core/services/notification_service.dart';

import 'package:dompetai/presentation/providers/profile_provider.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return "Selamat Pagi";
    } else if (hour >= 11 && hour < 15) {
      return "Selamat Siang";
    } else if (hour >= 15 && hour < 18) {
      return "Selamat Sore";
    } else {
      return "Selamat Malam";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String userName = ref.watch(userNameProvider);
    final String greeting = _getGreeting();

    // Gunakan ref.watch(debtsStreamProvider) untuk memantau data utang piutang
    final debtsAsync = ref.watch(debtsStreamProvider);
    final now = DateTime.now();

    List<Debt> urgentDebts = [];
    bool hasUrgentDebt = false;

    debtsAsync.maybeWhen(
      data: (debts) {
        urgentDebts = debts.where((d) {
          if (d.isPaid) return false;
          if (d.dueDate == null) return false;
          // Selisih hari kurang dari atau sama dengan 3 hari
          final difference = d.dueDate!.difference(now).inDays;
          return difference <= 3;
        }).toList();
        hasUrgentDebt = urgentDebts.isNotEmpty;
      },
      orElse: () {},
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$greeting, $userName! 👋",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFE4E1E6) : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Kelola keuanganmu hari ini",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Notification Bell dengan Dot Aksen Glow Indigo/Zinc
          GestureDetector(
            onTap: () {
              if (hasUrgentDebt) {
                // Picu NotificationService.showDebtReminder untuk setiap utang mendesak
                for (final debt in urgentDebts) {
                  NotificationService.showDebtReminder(
                    id: debt.id ?? debt.title.hashCode,
                    name: debt.title,
                    description: 'Jatuh tempo dalam waktu dekat.',
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Simulasi notifikasi dikirim untuk utang mendesak!'),
                    backgroundColor: Colors.black,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tidak ada utang mendesak saat ini.'),
                    backgroundColor: Colors.grey,
                  ),
                );
              }
            },
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_outlined,
                    color: Color(0xFFC7C4D7),
                    size: 24,
                  ),
                ),
                if (hasUrgentDebt)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.redAccent, // Red dot for urgent debt
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF131316), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}