import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../domain/entities/transaction_entity.dart';

enum MessageSender { user, ai }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final List<TransactionEntity> transactions;
  final List<bool> confirmedStatuses;
  final bool isLoading;
  final String? error;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.transactions = const [],
    this.confirmedStatuses = const [],
    this.isLoading = false,
    this.error,
  });

  // Backward compatibility getter
  TransactionEntity? get transaction => transactions.isNotEmpty ? transactions.first : null;
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;

  ChatNotifier(this._ref) : super([]);

  Future<void> sendMessage(String text) async {
    final String userMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    final userMessage = ChatMessage(
      id: userMsgId,
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    // Append user message to state
    state = [...state, userMessage];

    // Append loading message for AI response
    final String aiMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    final loadingMessage = ChatMessage(
      id: aiMsgId,
      text: '',
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    state = [...state, loadingMessage];

    try {
      final parser = await _ref.read(nerParserProvider.future);
      final parsedTransactions = await parser.parseAll(text);

      final repository = await _ref.read(transactionRepositoryProvider.future);
      
      final isMulti = parsedTransactions.length > 1;
      final List<bool> confirmed = [];
      
      if (isMulti) {
        // Multi-transaction: do NOT save automatically. Show as drafts.
        for (int i = 0; i < parsedTransactions.length; i++) {
          confirmed.add(false);
        }
      } else if (parsedTransactions.isNotEmpty) {
        final tx = parsedTransactions.first;
        if (tx.amount == null || tx.amount == 0) {
          // Incomplete amount: do NOT save automatically. Needs review.
          confirmed.add(false);
        } else {
          // Single transaction: auto-save to DB.
          await repository.saveTransaction(tx);
          confirmed.add(true);
        }
      }

      // Map success state into the loading message
      state = state.map((msg) {
        if (msg.id == aiMsgId) {
          final showDraftWarning = !isMulti && confirmed.isNotEmpty && !confirmed.first;
          return ChatMessage(
            id: aiMsgId,
            text: isMulti 
                ? 'Saya menemukan beberapa transaksi dalam kalimat Anda. Silakan simpan atau edit draf di bawah ini:' 
                : showDraftWarning
                    ? 'Transaksi berhasil dideteksi, tetapi nominal belum lengkap. Silakan edit dan simpan draf di bawah ini:'
                    : 'Transaksi berhasil dicatat!',
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
            transactions: parsedTransactions,
            confirmedStatuses: confirmed,
            isLoading: false,
          );
        }
        return msg;
      }).toList();
    } catch (e) {
      // Map error state into the loading message
      state = state.map((msg) {
        if (msg.id == aiMsgId) {
          return ChatMessage(
            id: aiMsgId,
            text: 'Sorry, I couldn\'t process that: $e',
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
            isLoading: false,
            error: e.toString(),
          );
        }
        return msg;
      }).toList();
    }
  }

  Future<void> confirmTransaction(String messageId, int index) async {
    final repository = await _ref.read(transactionRepositoryProvider.future);
    
    state = state.map((msg) {
      if (msg.id == messageId) {
        final updatedStatuses = List<bool>.from(msg.confirmedStatuses);
        if (index < updatedStatuses.length && !updatedStatuses[index]) {
          updatedStatuses[index] = true;
          
          // Save to repository
          final tx = msg.transactions[index];
          repository.saveTransaction(tx);
          
          return ChatMessage(
            id: msg.id,
            text: msg.text,
            sender: msg.sender,
            timestamp: msg.timestamp,
            transactions: msg.transactions,
            confirmedStatuses: updatedStatuses,
            isLoading: msg.isLoading,
            error: msg.error,
          );
        }
      }
      return msg;
    }).toList();
  }

  Future<void> updateTransaction(String messageId, int index, TransactionEntity updatedTx) async {
    final repository = await _ref.read(transactionRepositoryProvider.future);
    
    state = state.map((msg) {
      if (msg.id == messageId) {
        final updatedTxs = List<TransactionEntity>.from(msg.transactions);
        final updatedStatuses = List<bool>.from(msg.confirmedStatuses);
        
        if (index < updatedTxs.length) {
          updatedTxs[index] = updatedTx;
          // Mark as confirmed and save to DB
          updatedStatuses[index] = true;
          repository.saveTransaction(updatedTx);
          
          return ChatMessage(
            id: msg.id,
            text: msg.text,
            sender: msg.sender,
            timestamp: msg.timestamp,
            transactions: updatedTxs,
            confirmedStatuses: updatedStatuses,
            isLoading: msg.isLoading,
            error: msg.error,
          );
        }
      }
      return msg;
    }).toList();
  }

  void deleteTransaction(String messageId, int index) {
    state = state.map((msg) {
      if (msg.id == messageId) {
        final updatedTxs = List<TransactionEntity>.from(msg.transactions);
        final updatedStatuses = List<bool>.from(msg.confirmedStatuses);
        
        if (index < updatedTxs.length) {
          updatedTxs.removeAt(index);
          updatedStatuses.removeAt(index);
          
          return ChatMessage(
            id: msg.id,
            text: updatedTxs.isEmpty ? 'Semua transaksi dibatalkan.' : msg.text,
            sender: msg.sender,
            timestamp: msg.timestamp,
            transactions: updatedTxs,
            confirmedStatuses: updatedStatuses,
            isLoading: msg.isLoading,
            error: msg.error,
          );
        }
      }
      return msg;
    }).toList();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});
