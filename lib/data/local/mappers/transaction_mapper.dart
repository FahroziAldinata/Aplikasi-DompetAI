import 'package:drift/drift.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../app_database.dart';

extension TransactionMapper on Transaction {
  TransactionEntity toEntity() {
    String resolvedName = 'Dompet Utama';
    String resolvedType = 'CASH';
    
    final acc = (account ?? '').toLowerCase().trim();
    if (acc == 'cash' || acc == 'tunai' || acc == 'dompet utama') {
      resolvedName = 'Dompet Utama';
      resolvedType = 'CASH';
    } else if (acc == 'gopay') {
      resolvedName = 'GoPay';
      resolvedType = 'REKENING';
    } else if (acc == 'bca') {
      resolvedName = 'BCA';
      resolvedType = 'REKENING';
    } else if (acc == 'rekening') {
      resolvedName = 'BCA';
      resolvedType = 'REKENING';
    } else if (acc.isNotEmpty) {
      resolvedName = acc[0].toUpperCase() + acc.substring(1);
      resolvedType = 'REKENING';
    }

    return TransactionEntity(
      id: id,
      rawText: rawText,
      intent: intent,
      category: category,
      amount: amount,
      account: account,
      description: description,
      createdAt: createdAt,
      confidence: confidence,
      accountType: accountType ?? resolvedType,
      accountName: accountName ?? resolvedName,
    );
  }
}

extension TransactionEntityMapper on TransactionEntity {
  TransactionsCompanion toCompanion() {
    String resolvedName = 'Dompet Utama';
    String resolvedType = 'CASH';
    
    final acc = (account ?? '').toLowerCase().trim();
    if (acc == 'cash' || acc == 'tunai' || acc == 'dompet utama') {
      resolvedName = 'Dompet Utama';
      resolvedType = 'CASH';
    } else if (acc == 'gopay') {
      resolvedName = 'GoPay';
      resolvedType = 'REKENING';
    } else if (acc == 'bca') {
      resolvedName = 'BCA';
      resolvedType = 'REKENING';
    } else if (acc == 'rekening') {
      resolvedName = 'BCA';
      resolvedType = 'REKENING';
    } else if (acc.isNotEmpty) {
      resolvedName = acc[0].toUpperCase() + acc.substring(1);
      resolvedType = 'REKENING';
    }

    return TransactionsCompanion(
      id: Value(id),
      rawText: Value(rawText),
      intent: Value(intent),
      category: Value(category),
      amount: Value(amount),
      account: Value(account),
      description: Value(description),
      createdAt: Value(createdAt),
      confidence: Value(confidence),
      accountType: Value(accountType ?? resolvedType),
      accountName: Value(accountName ?? resolvedName),
    );
  }
}
