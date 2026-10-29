import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/date_order.dart';
import '../widgets/order_event_card.dart';
import '../widgets/order_sync_panel.dart';

/// Conversation thread with the live order panel and order event cards.
class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.repository,
    required this.conversation,
  });

  final ChatRepository repository;
  final Conversation conversation;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<ConversationSnapshot>? _subscription;
  late Conversation _conversation = widget.conversation;
  List<ChatMessage> _messages = <ChatMessage>[];
  bool _isLoading = true;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository
        .watchConversation(widget.conversation.id)
        .listen(_onSnapshot);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSnapshot(ConversationSnapshot snapshot) {
    setState(() {
      _conversation = snapshot.conversation;
      _messages = snapshot.messages;
      _isLoading = false;
      if (snapshot.conversation.order?.isCompleted ?? false) {
        _isCompleting = false;
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    await widget.repository.sendMessage(_conversation.id, text);
  }

  Future<void> _complete() async {
    setState(() => _isCompleting = true);
    await widget.repository.completeOrder(_conversation.id);
  }

  String get _subtitle {
    final DateOrder? order = _conversation.order;
    if (order == null) {
      return AppStrings.officialNotice;
    }
    final String state = order.isCompleted
        ? AppStrings.statusCompleted
        : order.bothArrived
            ? AppStrings.stateMeeting
            : AppStrings.statusBooked;
    return '$state \u00b7 ${order.title}';
  }

  @override
  Widget build(BuildContext context) {
    final DateOrder? order = _conversation.order;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _conversation.peerName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (order != null)
              OrderSyncPanel(
                order: order,
                peerName: _conversation.peerName,
                peerAvatarUrl: _conversation.peerAvatarUrl,
                myAvatarUrl: AuthSession.currentUserAvatarUrl,
                isCompleting: _isCompleting,
                onDepart: () =>
                    widget.repository.departOrder(_conversation.id),
                onArrive: () =>
                    widget.repository.arriveOrder(_conversation.id),
                onComplete: _complete,
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final ChatMessage message = _messages[index];
                        if (message.type == ChatMessageType.orderEvent) {
                          return OrderEventCard(
                            message: message,
                            order: order,
                          );
                        }
                        return _MessageBubble(message: message);
                      },
                    ),
            ),
            _InputBar(controller: _inputController, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.myMessageBubble
              : AppColors.otherMessageBubble,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMine ? const Radius.circular(4) : null,
            bottomLeft: isMine ? null : const Radius.circular(4),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: isMine ? AppColors.myMessageText : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: AppStrings.messageInputHint,
              ),
            ),
          ),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Iconsax.send_1, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
