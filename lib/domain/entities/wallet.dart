class WalletEntity {
  final String id;
  final String name;
  final String type; // CASH or REKENING
  final int initialBalance;
  final DateTime createdAt;

  const WalletEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.createdAt,
  });
}

class WalletSummary {
  final WalletEntity wallet;
  final double balance;

  const WalletSummary({
    required this.wallet,
    required this.balance,
  });
}
