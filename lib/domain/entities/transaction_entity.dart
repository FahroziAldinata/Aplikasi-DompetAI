class TransactionEntity {
  final String id;
  final String rawText;
  final String intent; // expense/income/transfer/debt
  final String? category;
  final int? amount;
  final String? account;
  final String? description;
  final DateTime createdAt;
  final double confidence;
  final String? accountType;
  final String? accountName;

  const TransactionEntity({
    required this.id,
    required this.rawText,
    required this.intent,
    this.category,
    this.amount,
    this.account,
    this.description,
    required this.createdAt,
    required this.confidence,
    this.accountType,
    this.accountName,
  });

  factory TransactionEntity.empty() {
    return TransactionEntity(
      id: '',
      rawText: '',
      intent: 'expense',
      category: null,
      amount: null,
      account: null,
      description: null,
      createdAt: DateTime.now(),
      confidence: 0.0,
      accountType: null,
      accountName: null,
    );
  }
}
