/// Kind of a chat message.
enum ChatMessageType {
  text,

  /// System-issued order event card (deal confirmed, departed, completed...).
  orderEvent;

  static ChatMessageType fromJson(String value) {
    return ChatMessageType.values
        .firstWhere((ChatMessageType e) => e.name == value);
  }
}

/// Icon hint for an order event card.
enum OrderEventIcon {
  deal,

  /// Match fee paid and held by the platform.
  escrow,
  enRoute,
  arrived,
  completed;

  static OrderEventIcon fromJson(String value) {
    return OrderEventIcon.values
        .firstWhere((OrderEventIcon e) => e.name == value);
  }
}

/// A single message inside a conversation: either a plain text bubble or an
/// order event card.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.sentAt,
    this.text = '',
    this.isMine = false,
    this.eventIcon,
    this.eventTitle,
    this.eventSubtitle,
    this.showsMap = false,
    this.isHighlighted = false,
  });

  factory ChatMessage.text({
    required String id,
    required String conversationId,
    required String text,
    required DateTime sentAt,
    required bool isMine,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      type: ChatMessageType.text,
      text: text,
      sentAt: sentAt,
      isMine: isMine,
    );
  }

  factory ChatMessage.orderEvent({
    required String id,
    required String conversationId,
    required DateTime sentAt,
    required OrderEventIcon icon,
    required String title,
    required String subtitle,
    bool showsMap = false,
    bool isHighlighted = false,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      type: ChatMessageType.orderEvent,
      sentAt: sentAt,
      eventIcon: icon,
      eventTitle: title,
      eventSubtitle: subtitle,
      showsMap: showsMap,
      isHighlighted: isHighlighted,
    );
  }

  final String id;
  final String conversationId;
  final ChatMessageType type;
  final DateTime sentAt;

  // Text message fields.
  final String text;
  final bool isMine;

  // Order event fields.
  final OrderEventIcon? eventIcon;
  final String? eventTitle;
  final String? eventSubtitle;

  /// Whether the event card embeds a route map preview.
  final bool showsMap;

  /// Completed-style emphasis (e.g. tip settled card).
  final bool isHighlighted;
}
