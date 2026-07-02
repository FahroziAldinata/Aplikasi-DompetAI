import 'debt_type.dart';

class Debt {
  final int? id;
  final String title;
  final double totalAmount;
  final double remainingAmount;
  final DebtType type;
  final DateTime? dueDate;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Debt({
    this.id,
    required this.title,
    required this.totalAmount,
    required this.remainingAmount,
    required this.type,
    this.dueDate,
    required this.isPaid,
    required this.createdAt,
    required this.updatedAt,
  });

  Debt copyWith({
    int? id,
    String? title,
    double? totalAmount,
    double? remainingAmount,
    DebtType? type,
    DateTime? dueDate,
    bool? isPaid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
