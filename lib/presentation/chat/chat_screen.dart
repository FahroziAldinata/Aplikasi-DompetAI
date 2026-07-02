import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'chat_provider.dart';
import '../../domain/entities/transaction_entity.dart';
import 'package:dompetai/presentation/widgets/profile_avatar.dart';
import 'package:dompetai/presentation/widgets/theme_toggle_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _controller.clear();
      ref.read(chatProvider.notifier).sendMessage(text);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, // With reverse: true, 0.0 is the bottom (latest messages)
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Auto-scroll when new messages arrive
    ref.listen<List<ChatMessage>>(chatProvider, (previous, next) {
      if (next.length != previous?.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0.0,
        title: Text(
          'DompetAI',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ProfileAvatar(radius: 18.0),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 64.0,
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16.0),
                          const Text(
                            'Tulis catatan transaksi Anda di sini\nContoh: "Beli kopi susu 15 ribu pakai Dana"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Show newest at the bottom
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        // Reverse mapping: 0 is the newest (end of messages array)
                        final message = messages[messages.length - 1 - index];
                        return _buildChatBubble(context, ref, message);
                      },
                    ),
            ),
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, WidgetRef ref, ChatMessage message) {
    final isUser = message.sender == MessageSender.user;
    final colorScheme = Theme.of(context).colorScheme;

    return FadeSlideIn(
      key: ValueKey('msg_${message.id}'),
      duration: const Duration(milliseconds: 200),
      delay: Duration.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: isUser
            ? Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white30, width: 1.0),
                    borderRadius: const BorderRadius.only(
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
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.0),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.wallet,
                          color: Colors.white,
                          size: 12.0,
                        ),
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.0,
                                    ),
                                  ),
                          ),
                          if (message.transactions.isNotEmpty) ...[
                            for (int i = 0; i < message.transactions.length; i++) ...[
                              const SizedBox(height: 10.0),
                              FadeSlideIn(
                                key: ValueKey('draft_${message.id}_$i'),
                                duration: const Duration(milliseconds: 200),
                                delay: const Duration(milliseconds: 50),
                                child: _buildDraftCard(context, ref, message, i),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDraftCard(BuildContext context, WidgetRef ref, ChatMessage message, int index) {
    final transaction = message.transactions[index];
    final isConfirmed = message.confirmedStatuses[index];
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

    // Determine intent badge styles
    final intentName = transaction.intent.toLowerCase();
    Color intentColor = Colors.redAccent;
    String intentLabel = "Expense";
    if (intentName == 'income') {
      intentColor = Colors.greenAccent;
      intentLabel = "Income";
    } else if (intentName == 'transfer') {
      intentColor = Colors.lightBlueAccent;
      intentLabel = "Transfer";
    } else if (intentName == 'debt') {
      intentColor = Colors.redAccent;
      intentLabel = "Debt";
    }

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
          // Top Row: Intent Badge (left) & Validation Badge (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: intentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: intentColor, width: 1.0),
                ),
                child: Text(
                  intentLabel,
                  style: TextStyle(
                    color: intentColor,
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: (isReview ? Colors.orangeAccent : Colors.greenAccent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: isReview ? Colors.orangeAccent : Colors.greenAccent, width: 1.0),
                ),
                child: Text(
                  isReview ? "Review" : "Valid",
                  style: TextStyle(
                    color: isReview ? Colors.orangeAccent : Colors.greenAccent,
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
              style: const TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),
          const SizedBox(height: 6.0),
          
          // Description / Name
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14.0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8.0),
          
          // Category Icon Row (Fill: Hitam, Border: Putih, Icon: Putih)
          Row(
            children: [
              Container(
                width: 24.0,
                height: 24.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.0),
                  color: Colors.black,
                  border: Border.all(color: Colors.white30, width: 1.0),
                ),
                child: Center(
                  child: Icon(
                    categoryIcon,
                    color: Colors.white,
                    size: 12.0,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                categoryName,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),

          if (isReview) ...[
            // Warning row below amount
            const SizedBox(height: 8.0),
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.tertiary, size: 14.0),
                const SizedBox(width: 6.0),
                Text(
                  "Very low amount. Confirm?",
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
                          ref.read(chatProvider.notifier).confirmTransaction(message.id, index);
                        },
                        child: const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold)),
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
                        _showEditDialog(context, ref, message.id, index, transaction);
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
                          ref.read(chatProvider.notifier).confirmTransaction(message.id, index);
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
                        _showEditDialog(context, ref, message.id, index, transaction);
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
                        ref.read(chatProvider.notifier).deleteTransaction(message.id, index);
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

  void _showEditDialog(BuildContext context, WidgetRef ref, String messageId, int index, TransactionEntity transaction) {
    showDialog(
      context: context,
      builder: (context) {
        return _EditTransactionDialog(
          transaction: transaction,
          onSave: (updatedTx) {
            ref.read(chatProvider.notifier).updateTransaction(messageId, index, updatedTx);
          },
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = viewInsets.bottom > 0 ? 0.0 : MediaQuery.of(context).padding.bottom;

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0 + bottomPadding),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Catat transaksi Anda di sini...',
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light ? Colors.grey : Colors.white38,
                ),
                border: InputBorder.none,
                filled: true,
                fillColor: colorScheme.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.transparent,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: Icon(Icons.mic, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              // placeholder, no function
            },
          ),
          IconButton(
            icon: Icon(Icons.send, color: colorScheme.primary),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// FadeSlideIn widget for message bubbles & draft cards
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.delay = Duration.zero,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// Edit dialog matching M3 tokens
class _EditTransactionDialog extends StatefulWidget {
  final TransactionEntity transaction;
  final Function(TransactionEntity) onSave;

  const _EditTransactionDialog({
    required this.transaction,
    required this.onSave,
  });

  @override
  State<_EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  late TextEditingController _amountController;
  late TextEditingController _descController;
  late TextEditingController _accountController;
  late String _intent;
  late String? _category;

  final List<String> _intents = ['expense', 'income', 'transfer', 'debt'];
  final List<String> _categories = [
    'makanan',
    'tagihan',
    'belanja',
    'transportasi',
    'pemasukan',
    'utang',
    'transfer',
    'lainnya'
  ];

  @override
  void initState() {
    super.initState();
    final formatter = NumberFormat('#,###', 'id_ID');
    final formattedInitial = widget.transaction.amount != null
        ? formatter.format(widget.transaction.amount)
        : '';
    _amountController = TextEditingController(text: formattedInitial);

    _amountController.addListener(() {
      final text = _amountController.text
          .replaceAll('.', '')
          .replaceAll(',', '');
      if (text.isEmpty) return;

      final number = int.tryParse(text);
      if (number == null) return;

      final formatted = formatter.format(number);
      if (formatted != _amountController.text) {
        _amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(
            offset: formatted.length,
          ),
        );
      }
    });

    _descController = TextEditingController(text: widget.transaction.description ?? '');
    _accountController = TextEditingController(text: widget.transaction.account ?? '');
    _intent = widget.transaction.intent;
    _category = widget.transaction.category;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainer,
      title: Text('Edit Transaksi', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tipe Transaksi', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.0, color: colorScheme.onSurface)),
            const SizedBox(height: 6.0),
            DropdownButtonFormField<String>(
              initialValue: _intent,
              dropdownColor: colorScheme.surfaceContainer,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              ),
              items: _intents.map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase(), style: TextStyle(color: colorScheme.onSurface)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _intent = val;
                    if (val == 'income') {
                      _category = 'pemasukan';
                    } else if (val == 'transfer') {
                      _category = 'transfer';
                    } else if (val == 'debt') {
                      _category = 'utang';
                    } else {
                      _category = 'makanan';
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16.0),

            Text('Nominal (Rp)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.0, color: colorScheme.onSurface)),
            const SizedBox(height: 6.0),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: 'Masukkan nominal',
                hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              ),
            ),
            const SizedBox(height: 16.0),

            Text('Kategori', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.0, color: colorScheme.onSurface)),
            const SizedBox(height: 6.0),
            DropdownButtonFormField<String>(
              initialValue: _categories.contains(_category) ? _category : 'lainnya',
              dropdownColor: colorScheme.surfaceContainer,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : colorScheme.onSurface)))).toList(),
              onChanged: (val) {
                setState(() {
                  _category = val;
                });
              },
            ),
            const SizedBox(height: 16.0),

            Text('Sumber Dana / Akun', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.0, color: colorScheme.onSurface)),
            const SizedBox(height: 6.0),
            TextField(
              controller: _accountController,
              style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              decoration: InputDecoration(
                hintText: 'Contoh: Cash, BCA, OVO',
                hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              ),
            ),
            const SizedBox(height: 16.0),

            Text('Keterangan', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.0, color: colorScheme.onSurface)),
            const SizedBox(height: 6.0),
            TextField(
              controller: _descController,
              style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white),
              decoration: InputDecoration(
                hintText: 'Detail belanjaan',
                hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey : colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Batal', style: TextStyle(color: colorScheme.outline)),
        ),
        ElevatedButton(
          onPressed: () {
            final cleanAmtStr = _amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
            final amt = int.tryParse(cleanAmtStr) ?? 0;
            final updated = TransactionEntity(
              id: widget.transaction.id,
              rawText: widget.transaction.rawText,
              intent: _intent,
              category: _category == 'lainnya' ? null : _category,
              amount: amt > 0 ? amt : null,
              account: _accountController.text.trim().isNotEmpty ? _accountController.text.trim() : null,
              description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
              createdAt: widget.transaction.createdAt,
              confidence: 1.0,
            );
            widget.onSave(updated);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
