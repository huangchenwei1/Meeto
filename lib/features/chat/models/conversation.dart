import 'date_order.dart';

/// A conversation summary shown in the chat list.
class Conversation {
  const Conversation({
    required this.id,
    required this.peerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.peerAvatarUrl,
    this.isOfficial = false,
    this.order,
  });

  final String id;
  final String peerName;

  /// Null for the official account, which renders a letter avatar instead.
  final String? peerAvatarUrl;

  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  /// Platform announcement account.
  final bool isOfficial;

  /// The confirmed date bound to this conversation, if any.
  final DateOrder? order;

  Conversation copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    DateOrder? order,
  }) {
    return Conversation(
      id: id,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isOfficial: isOfficial,
      order: order ?? this.order,
    );
  }
}
