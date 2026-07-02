import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:drift/drift.dart';
import '../../data/local/app_database.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        final actionId = response.actionId;
        if (actionId == 'buka_chat' || actionId == 'action_chat') {
          debugPrint('Notification Quick Action: Buka Chat AI triggered with payload: $payload');
        } else if (actionId == 'tandai_lunas' || actionId == 'action_pay') {
          if (payload != null) {
            final debtId = int.tryParse(payload);
            if (debtId != null) {
              final db = AppDatabase.instance;
              await (db.update(db.debts)..where((d) => d.id.equals(debtId))).write(
                DebtsCompanion(
                  remainingAmount: const Value(0.0),
                  isPaid: const Value(true),
                  updatedAt: Value(DateTime.now()),
                ),
              );
              debugPrint('Notification Quick Action: Debt ID $debtId marked as paid in DB.');
            }
          }
        }
      },
    );
  }

  // Fungsi memicu notifikasi pengingat utang dengan Quick Action Buttons sesuai desain
  static Future<void> showDebtReminder({
    required int id,
    required String name,
    required String description,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'debt_reminders',
      'Debt Reminders',
      channelDescription: 'Notification channel for financial debt reminders',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'buka_chat',
          'Buka Chat AI',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'tandai_lunas',
          'Tandai Lunas',
          showsUserInterface: false,
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      'Pengingat Utang 🗓️',
      'Tagihan utang ke $name jatuh tempo besok, nih. Yuk catat atau update statusnya!',
      notificationDetails,
      payload: id.toString(),
    );
  }

  // Keep compatibility for older callers
  static Future<void> showDebtReminderNotification({
    required String debtName,
    required double amount,
    required DateTime dueDate,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'debt_reminder_channel',
      'Debt Reminders',
      channelDescription: 'Channel for debt due reminders',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_chat',
          'Buka Chat AI',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_pay',
          'Tandai Lunas',
          showsUserInterface: false,
        ),
      ],
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final formattedAmount = amount.toStringAsFixed(0);
    final daysLeft = dueDate.difference(DateTime.now()).inDays;
    final timeText = daysLeft == 0
        ? 'hari ini'
        : (daysLeft < 0 ? 'telah lewat ${-daysLeft} hari' : 'dalam $daysLeft hari');

    await _notificationsPlugin.show(
      debtName.hashCode,
      'Pengingat Utang: $debtName',
      'Tagihan sebesar Rp $formattedAmount jatuh tempo $timeText.',
      platformChannelSpecifics,
      payload: debtName,
    );
  }
}
