import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../chat_provider.dart';

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.sender == MessageSender.user;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: isUser
          ? Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: const BoxDecoration(
                  color: Color(0xFF4A4580), // muted indigo-purple
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18.0),
                    topRight: Radius.circular(18.0),
                    bottomLeft: Radius.circular(18.0),
                    bottomRight: Radius.circular(4.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12.0,
                    backgroundColor: colorScheme.primaryContainer,
                    child: const Icon(
                      Icons.wallet,
                      color: Colors.white,
                      size: 14.0,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2D), // surfaceContainerHigh
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18.0),
                              topRight: Radius.circular(18.0),
                              bottomLeft: Radius.circular(4.0),
                              bottomRight: Radius.circular(18.0),
                            ),
                          ),
                          child: message.isLoading
                              ? SizedBox(
                                  width: 20.0,
                                  height: 20.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                  ),
                                )
                              : Text(
                                  message.text,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 14.0,
                                  ),
                                ),
                        ),
                        if (message.transactions.isNotEmpty) ...[
                          for (int i = 0; i < message.transactions.length; i++) ...[
                            const SizedBox(height: 10.0),
                            _TransactionCard(
                              transaction: message.transactions[i],
                              isConfirmed: message.confirmedStatuses[i],
                              messageId: message.id,
                              index: i,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  final TransactionEntity transaction;
  final bool isConfirmed;
  final String messageId;
  final int index;

  const _TransactionCard({
    required this.transaction,
    required this.isConfirmed,
    required this.messageId,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // REVIEW card condition: confidence < 0.65 or amount null
    final isReview = !isConfirmed && (transaction.confidence < 0.65 || transaction.amount == null);

    final rupiahFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final nominal = transaction.amount != null ? rupiahFormat.format(transaction.amount) : 'Rp -';
    final name = transaction.description ?? transaction.category ?? 'Transaksi';

    // Emoji/Icon mapping
    IconData categoryIcon = Icons.restaurant;
    final catLower = (transaction.category ?? '').toLowerCase().trim();
    if (catLower == 'makanan' || catLower == 'minuman' || catLower == 'kuliner') {
      categoryIcon = Icons.restaurant;
    } else if (catLower == 'tagihan' || catLower == 'listrik' || catLower == 'pulsa') {
      categoryIcon = Icons.bolt;
    } else if (catLower == 'belanja' || catLower == 'shopping') {
      categoryIcon = Icons.shopping_bag;
    } else if (catLower == 'transportasi' || catLower == 'ojek') {
      categoryIcon = Icons.directions_car;
    } else if (catLower == 'pemasukan' || catLower == 'gaji') {
      categoryIcon = Icons.monetization_on;
    } else if (catLower == 'utang' || catLower == 'piutang') {
      categoryIcon = Icons.handshake;
    } else if (catLower == 'transfer') {
      categoryIcon = Icons.swap_horiz;
    }

    final categoryName = transaction.category != null 
        ? "${transaction.category![0].toUpperCase()}${transaction.category!.substring(1)}"
        : "Lainnya";

    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F22), // surfaceContainer
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: isReview ? colorScheme.tertiaryContainer : colorScheme.primaryContainer,
                ),
                child: Center(
                  child: Icon(
                    categoryIcon,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
                      categoryName,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: (isReview ? colorScheme.tertiary : colorScheme.primary).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  isReview ? "PERIKSA" : "VALID",
                  style: TextStyle(
                    color: isReview ? colorScheme.tertiary : colorScheme.primary,
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          // Amount
          Container(
            margin: const EdgeInsets.only(top: 12.0),
            child: Text(
              nominal,
              style: TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                color: isReview ? colorScheme.tertiary : colorScheme.primary,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),

          if (isReview) ...[
            // Warning row below amount
            const SizedBox(height: 8.0),
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.tertiary, size: 14.0),
                const SizedBox(width: 6.0),
                Text(
                  "Nominal sangat rendah. Konfirmasi?",
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ],

          // Actions / Status row
          const SizedBox(height: 12.0),
          if (isConfirmed) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.check_circle_rounded, size: 16.0, color: Colors.green),
                SizedBox(width: 6.0),
                Text(
                  "Tercatat",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                if (isReview) ...[
                  // Actions: only 2 buttons: FilledButton "Confirm" (flex: 3), OutlinedButton edit
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 44.0,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.tertiaryContainer,
                          foregroundColor: colorScheme.onTertiary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {
                          ref.read(chatProvider.notifier).confirmTransaction(messageId, index);
                        },
                        child: const Text("Konfirmasi", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  SizedBox(
                    width: 44.0,
                    height: 44.0,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        _showEditDialog(context, ref, messageId, index, transaction);
                      },
                      child: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
                    ),
                  ),
                ] else ...[
                  // Actions: 3 buttons: FilledButton "✓", OutlinedButton edit, OutlinedButton delete
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 44.0,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {
                          ref.read(chatProvider.notifier).confirmTransaction(messageId, index);
                        },
                        child: const Icon(Icons.check, size: 20.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  SizedBox(
                    width: 44.0,
                    height: 44.0,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        _showEditDialog(context, ref, messageId, index, transaction);
                      },
                      child: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  SizedBox(
                    width: 44.0,
                    height: 44.0,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        ref.read(chatProvider.notifier).deleteTransaction(messageId, index);
                      },
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ),
                ]
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String msgId, int idx, TransactionEntity tx) {
    showDialog(
      context: context,
      builder: (context) {
        // Reuse original dialog from ChatScreen but keep it clean
        // We will just allow standard edit
        return AlertDialog(
          title: const Text('Edit Transaksi'),
          content: const Text('Gunakan halaman Chat utama untuk mengedit transaksi secara detail.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
