import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DebtDateHelper {
  static String formatFriendlyDueDate(DateTime? dueDate, DateTime today, bool isPaid) {
    if (dueDate == null) {
      return "Tanpa jatuh tempo";
    }

    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = dueDateOnly.difference(todayDate).inDays;

    final dateFormatted = DateFormat('d MMM yyyy', 'id_ID').format(dueDate);

    if (isPaid) {
      return dateFormatted;
    }

    if (diff == 0) {
      return "Hari ini ($dateFormatted)";
    } else if (diff == 1) {
      return "Besok ($dateFormatted)";
    } else if (diff > 1) {
      return "$diff hari lagi ($dateFormatted)";
    } else if (diff == -1) {
      return "Terlambat 1 hari ($dateFormatted)";
    } else {
      return "Terlambat ${-diff} hari ($dateFormatted)";
    }
  }

  static Color getDueDateColor(DateTime? dueDate, DateTime today, bool isPaid) {
    if (dueDate == null || isPaid) {
      return Colors.grey;
    }

    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = dueDateOnly.difference(todayDate).inDays;

    if (diff < 0) {
      return Colors.redAccent;
    } else if (diff <= 3) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }
}
