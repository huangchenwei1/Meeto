import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/chat_repository.dart';
import '../models/conversation.dart';
import 'chat_detail_page.dart';

/// Chats tab: wallet notice + conversation list with order status pills.
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key, required this.repository});

  final ChatRepository repository;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Conversation> _conversations = <Conversation>[];
  bool _isLoading = true;
  StreamSubscription<void>? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    // Reload when new deal conversations appear (e.g. a match formed).
    _changesSubscription =
        widget.repository.conversationsChanged.listen((_) {
      _loadConversations();
    });
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final List<Conversation> conversations =
        await widget.repository.fetchConversations();
    if (!mounted) {
      return;
    }
    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
  }

  Future<void> _openConversation(Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailPage(
          repository: widget.repository,
          conversation: conversation,
        ),
      ),
    );
    // Refresh pills/last messages after order progress in the detail page.
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.tabChats)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Text(
                    AppStrings.emptyChatList,
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : ListView(
                  children: <Widget>[
                    const _WalletNotice(),
                    ..._conversations.map(
                      (Conversation c) => _ConversationTile(
                        conversation: c,
                        onTap: () => _openConversation(c),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _WalletNotice extends StatelessWidget {
  const _WalletNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: const <Widget>[
          Icon(Iconsax.wallet_35, size: 17, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.chatNotice,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasOrder = conversation.order != null;
    final bool done = conversation.order?.isCompleted ?? false;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AppAvatar(
        size: 48,
        imageUrl: conversation.peerAvatarUrl,
        fallbackLetter: conversation.peerName.characters.first,
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              conversation.peerName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (hasOrder) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                border: Border.all(
                  color: done ? AppColors.textHint : AppColors.accent,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                done ? AppStrings.statusCompleted : AppStrings.statusBooked,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: done ? AppColors.textHint : AppColors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          conversation.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            conversation.lastMessageAt.toRelativeLabel(),
            style: const TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onDarkPrimary,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}
