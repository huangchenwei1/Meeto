import 'dart:async';
import 'dart:math' as math;

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/utils/money.dart';
import '../../partner/models/date_post.dart';
import '../../partner/models/post_author.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/date_order.dart';

/// Snapshot of one conversation: its summary (incl. order state) plus the
/// full message list. Streamed to the chat detail page on every change.
class ConversationSnapshot {
  const ConversationSnapshot({
    required this.conversation,
    required this.messages,
  });

  final Conversation conversation;
  final List<ChatMessage> messages;
}

/// Data source contract for conversations, messages and order actions.
///
/// DEMO NOTE: the mock advances the order state machine locally and fakes the
/// peer's reactions with timers. In production:
/// - messages and snapshots arrive through an IM provider (push, not poll);
/// - order transitions are server-authoritative; the client only sends
///   intents and renders the pushed state.
abstract interface class ChatRepository {
  Future<List<Conversation>> fetchConversations();

  /// Fires whenever the conversation list changes (e.g. a new match formed).
  Stream<void> get conversationsChanged;

  /// Creates the conversation + order after a match forms: [payer] (always
  /// the male side) has paid the platform-set fee into escrow.
  ///
  /// DEMO NOTE: in production this happens server-side on payment success
  /// and reaches the client via IM push; the client never creates orders.
  Future<Conversation> createDealConversation({
    required DatePost post,
    required PostAuthor payer,
  });

  /// Emits the current snapshot immediately, then again on every change.
  Stream<ConversationSnapshot> watchConversation(String conversationId);

  Future<void> sendMessage(String conversationId, String text);

  /// Order intents. The updated state arrives via [watchConversation].
  Future<void> departOrder(String conversationId);
  Future<void> arriveOrder(String conversationId);
  Future<void> completeOrder(String conversationId);
}

/// In-memory mock used for the standalone demo build. API mode uses the
/// server-backed orders feature instead (see features/orders).
class MockChatRepository implements ChatRepository {
  MockChatRepository() {
    _seed();
  }

  final Map<String, Conversation> _conversations = <String, Conversation>{};
  final Map<String, List<ChatMessage>> _messages =
      <String, List<ChatMessage>>{};
  final Map<String, StreamController<ConversationSnapshot>> _controllers =
      <String, StreamController<ConversationSnapshot>>{};
  final StreamController<void> _conversationsChanged =
      StreamController<void>.broadcast();
  final List<String> _order = <String>[];
  int _messageSequence = 0;
  int _conversationSequence = 0;

  @override
  Stream<void> get conversationsChanged => _conversationsChanged.stream;

  void _seed() {
    final DateTime now = DateTime.now();

    // Marco: completed bar date (full history of the order flow).
    _addConversation(
      Conversation(
        id: 'conv-marco',
        peerName: 'Marco',
        peerAvatarUrl: 'https://i.pravatar.cc/150?img=12',
        lastMessage: 'That was a great evening, let\u2019s do it again!',
        lastMessageAt: now.subtract(const Duration(minutes: 12)),
        unreadCount: 2,
        order: const DateOrder(
          id: 'order-001',
          title: 'Drinks at a quiet bar',
          timeText: 'Friday 9:00 PM \u00b7 ~2 hours',
          place: 'The Spirits Library',
          distanceKm: 3.5,
          etaMinutes: 12,
          tipAmount: 1400,
          myStage: OrderStage.arrived,
          peerStage: OrderStage.arrived,
          isCompleted: true,
        ),
      ),
      <ChatMessage>[
        _event(
          'conv-marco',
          now.subtract(const Duration(hours: 6)),
          OrderEventIcon.deal,
          AppStrings.dealTitle('Drinks at a quiet bar'),
          AppStrings.dealSub(
            'Friday 9:00 PM \u00b7 ~2 hours',
            MoneyFormat.format(1400),
          ),
        ),
        _event(
          'conv-marco',
          now.subtract(const Duration(hours: 6)),
          OrderEventIcon.escrow,
          AppStrings.escrowTitle('Marco', MoneyFormat.format(1400)),
          AppStrings.escrowSub,
        ),
        _text('conv-marco', now.subtract(const Duration(hours: 5)),
            'Hi! Excited for Friday \u2014 are you really free?', false),
        _text('conv-marco', now.subtract(const Duration(hours: 5)),
            'Yes! I can make it before 9, The Spirits Library right?', true),
        _text('conv-marco', now.subtract(const Duration(hours: 5)),
            'Yup, it\u2019s quiet there, perfect for a long chat', false),
        _event(
          'conv-marco',
          now.subtract(const Duration(hours: 2)),
          OrderEventIcon.enRoute,
          AppStrings.departTitle,
          AppStrings.departSub('3.5', 'The Spirits Library', 12),
          showsMap: true,
        ),
        _text('conv-marco', now.subtract(const Duration(hours: 2)),
            'I\u2019m outside, the one in the black jacket', false),
        _event(
          'conv-marco',
          now.subtract(const Duration(hours: 2)),
          OrderEventIcon.arrived,
          AppStrings.meetTitle,
          AppStrings.meetSub,
        ),
        _event(
          'conv-marco',
          now.subtract(const Duration(minutes: 20)),
          OrderEventIcon.completed,
          AppStrings.finishTitle(
            MoneyFormat.format(ScenePricing.netEarnings(1400)),
          ),
          AppStrings.finishSub(
            MoneyFormat.format(1400),
            ScenePricing.platformFeeLabel,
          ),
          isHighlighted: true,
        ),
        _text('conv-marco', now.subtract(const Duration(minutes: 12)),
            'That was a great evening, let\u2019s do it again!', false),
      ],
    );

    // Rafael: booked movie date, nothing started yet (interactive demo flow).
    _addConversation(
      Conversation(
        id: 'conv-rafael',
        peerName: 'Rafael',
        peerAvatarUrl: 'https://i.pravatar.cc/150?img=33',
        lastMessage: 'Got the tickets, see you Saturday!',
        lastMessageAt: now.subtract(const Duration(hours: 3)),
        unreadCount: 0,
        order: const DateOrder(
          id: 'order-002',
          title: 'Movie date for the new release',
          timeText: 'Saturday 2:00 PM \u00b7 ~3 hours',
          place: 'SM Megamall Cinema',
          distanceKm: 4.6,
          etaMinutes: 18,
          tipAmount: 800,
          myStage: OrderStage.ready,
          peerStage: OrderStage.ready,
          isCompleted: false,
        ),
      ),
      <ChatMessage>[
        _event(
          'conv-rafael',
          now.subtract(const Duration(hours: 4)),
          OrderEventIcon.deal,
          AppStrings.dealTitle('Movie date for the new release'),
          AppStrings.dealSub(
            'Saturday 2:00 PM \u00b7 ~3 hours',
            MoneyFormat.format(800),
          ),
        ),
        _event(
          'conv-rafael',
          now.subtract(const Duration(hours: 4)),
          OrderEventIcon.escrow,
          AppStrings.escrowTitle('Rafael', MoneyFormat.format(800)),
          AppStrings.escrowSub,
        ),
        _text('conv-rafael', now.subtract(const Duration(hours: 4)),
            'Hi! Really looking forward to it \u2014 tickets are booked',
            false),
        _text('conv-rafael', now.subtract(const Duration(hours: 3)),
            'Yay! I\u2019ll be at the cinema entrance 30 mins early', true),
        _text('conv-rafael', now.subtract(const Duration(hours: 3)),
            'Got the tickets, see you Saturday!', false),
      ],
    );

    // Paolo: booked dinner date.
    _addConversation(
      Conversation(
        id: 'conv-paolo',
        peerName: 'Paolo',
        peerAvatarUrl: 'https://i.pravatar.cc/150?img=59',
        lastMessage: 'Table is booked for 7 PM tonight',
        lastMessageAt: now.subtract(const Duration(days: 1)),
        unreadCount: 1,
        order: const DateOrder(
          id: 'order-003',
          title: 'Japanese dinner date',
          timeText: 'Tonight 7:00 PM \u00b7 ~2 hours',
          place: 'Sushi Nori',
          distanceKm: 2.8,
          etaMinutes: 15,
          tipAmount: 1000,
          myStage: OrderStage.ready,
          peerStage: OrderStage.enRoute,
          isCompleted: false,
        ),
      ),
      <ChatMessage>[
        _event(
          'conv-paolo',
          now.subtract(const Duration(days: 1)),
          OrderEventIcon.deal,
          AppStrings.dealTitle('Japanese dinner date'),
          AppStrings.dealSub(
            'Tonight 7:00 PM \u00b7 ~2 hours',
            MoneyFormat.format(1000),
          ),
        ),
        _event(
          'conv-paolo',
          now.subtract(const Duration(days: 1)),
          OrderEventIcon.escrow,
          AppStrings.escrowTitle('Paolo', MoneyFormat.format(1000)),
          AppStrings.escrowSub,
        ),
        _text('conv-paolo', now.subtract(const Duration(days: 1)),
            'Hi! Table is booked for 7 PM tonight', false),
        _text('conv-paolo', now.subtract(const Duration(days: 1)),
            'Noted! I leave the office at 6:30, I\u2019ll make it', true),
        _text('conv-paolo', now.subtract(const Duration(days: 1)),
            'No rush \u2014 I\u2019ll head over first and wait for you there!',
            false),
      ],
    );

    // Official account.
    _addConversation(
      Conversation(
        id: 'conv-official',
        peerName: 'Meeto Official',
        peerAvatarUrl: null,
        isOfficial: true,
        lastMessage:
            'Your withdrawal of ${MoneyFormat.format(2500)} has arrived',
        lastMessageAt: now.subtract(const Duration(days: 1)),
        unreadCount: 0,
      ),
      <ChatMessage>[
        _text('conv-official', now.subtract(const Duration(days: 1)),
            'Your withdrawal of ${MoneyFormat.format(2500)} has arrived',
            false),
        _text(
            'conv-official',
            now.subtract(const Duration(days: 1)),
            'Newbie bonus: complete your first date this November for an '
            'extra ${MoneyFormat.format(250)}!',
            false),
      ],
    );
  }

  void _addConversation(Conversation conversation, List<ChatMessage> msgs) {
    _conversations[conversation.id] = conversation;
    _messages[conversation.id] = msgs;
    _order.add(conversation.id);
  }

  ChatMessage _text(
    String conversationId,
    DateTime sentAt,
    String text,
    bool isMine,
  ) {
    return ChatMessage.text(
      id: _nextMessageId(),
      conversationId: conversationId,
      text: text,
      sentAt: sentAt,
      isMine: isMine,
    );
  }

  ChatMessage _event(
    String conversationId,
    DateTime sentAt,
    OrderEventIcon icon,
    String title,
    String subtitle, {
    bool showsMap = false,
    bool isHighlighted = false,
  }) {
    return ChatMessage.orderEvent(
      id: _nextMessageId(),
      conversationId: conversationId,
      sentAt: sentAt,
      icon: icon,
      title: title,
      subtitle: subtitle,
      showsMap: showsMap,
      isHighlighted: isHighlighted,
    );
  }

  String _nextMessageId() =>
      'msg-${(++_messageSequence).toString().padLeft(4, '0')}';

  StreamController<ConversationSnapshot> _controllerFor(String id) {
    return _controllers.putIfAbsent(
      id,
      () => StreamController<ConversationSnapshot>.broadcast(),
    );
  }

  ConversationSnapshot _snapshot(String id) {
    return ConversationSnapshot(
      conversation: _conversations[id]!,
      messages: List<ChatMessage>.unmodifiable(_messages[id]!),
    );
  }

  void _emit(String id) {
    _controllerFor(id).add(_snapshot(id));
  }

  void _appendMessage(String id, ChatMessage message) {
    _messages[id]!.add(message);
    final bool isText = message.type == ChatMessageType.text;
    _conversations[id] = _conversations[id]!.copyWith(
      lastMessage: isText ? message.text : message.eventTitle,
      lastMessageAt: message.sentAt,
    );
  }

  void _updateOrder(String id, DateOrder order) {
    _conversations[id] = _conversations[id]!.copyWith(order: order);
  }

  @override
  Future<List<Conversation>> fetchConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _order
        .map((String id) => _conversations[id]!)
        .toList(growable: false);
  }

  @override
  Stream<ConversationSnapshot> watchConversation(String conversationId) {
    final StreamController<ConversationSnapshot> controller =
        _controllerFor(conversationId);
    // Emit the current state first, then live updates.
    return Stream<ConversationSnapshot>.multi(
        (StreamController<ConversationSnapshot> emitter) {
      emitter.add(_snapshot(conversationId));
      final StreamSubscription<ConversationSnapshot> sub =
          controller.stream.listen(emitter.add);
      emitter.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> sendMessage(String conversationId, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _appendMessage(
      conversationId,
      _text(conversationId, DateTime.now(), text, true),
    );
    _emit(conversationId);
  }

  @override
  Future<void> departOrder(String conversationId) async {
    final DateOrder order = _conversations[conversationId]!.order!;
    _updateOrder(
      conversationId,
      order.copyWith(myStage: OrderStage.enRoute),
    );
    _appendMessage(
      conversationId,
      _event(
        conversationId,
        DateTime.now(),
        OrderEventIcon.enRoute,
        AppStrings.departTitle,
        AppStrings.departSub(order.distanceLabel, order.place, order.etaMinutes),
        showsMap: true,
      ),
    );
    _emit(conversationId);

    // Simulated peer: departs shortly after me.
    if (order.peerStage == OrderStage.ready) {
      Timer(const Duration(milliseconds: 1500), () {
        final DateOrder current = _conversations[conversationId]!.order!;
        _updateOrder(
          conversationId,
          current.copyWith(peerStage: OrderStage.enRoute),
        );
        _appendMessage(
          conversationId,
          _text(conversationId, DateTime.now(), AppStrings.peerDepartedMsg,
              false),
        );
        _emit(conversationId);
      });
    }
  }

  @override
  Future<void> arriveOrder(String conversationId) async {
    final DateOrder order = _conversations[conversationId]!.order!;
    _updateOrder(
      conversationId,
      order.copyWith(myStage: OrderStage.arrived),
    );
    _appendMessage(
      conversationId,
      _event(
        conversationId,
        DateTime.now(),
        OrderEventIcon.arrived,
        AppStrings.arriveTitle,
        AppStrings.arriveSub,
      ),
    );
    _emit(conversationId);

    void pushMeet() {
      _appendMessage(
        conversationId,
        _event(
          conversationId,
          DateTime.now(),
          OrderEventIcon.arrived,
          AppStrings.meetTitle,
          AppStrings.meetSub,
        ),
      );
    }

    if (order.peerStage == OrderStage.arrived) {
      pushMeet();
      _emit(conversationId);
      return;
    }

    // Simulated peer: arrives shortly after me.
    Timer(const Duration(milliseconds: 1600), () {
      final DateOrder current = _conversations[conversationId]!.order!;
      _updateOrder(
        conversationId,
        current.copyWith(peerStage: OrderStage.arrived),
      );
      pushMeet();
      _emit(conversationId);
    });
  }

  @override
  Future<void> completeOrder(String conversationId) async {
    // Simulated peer confirmation delay before settlement.
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    final DateOrder order = _conversations[conversationId]!.order!;
    _updateOrder(conversationId, order.copyWith(isCompleted: true));
    _appendMessage(
      conversationId,
      _event(
        conversationId,
        DateTime.now(),
        OrderEventIcon.completed,
        AppStrings.finishTitle(
          MoneyFormat.format(ScenePricing.netEarnings(order.tipAmount)),
        ),
        AppStrings.finishSub(
          MoneyFormat.format(order.tipAmount),
          ScenePricing.platformFeeLabel,
        ),
        isHighlighted: true,
      ),
    );
    _emit(conversationId);
  }

  @override
  Future<Conversation> createDealConversation({
    required DatePost post,
    required PostAuthor payer,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Demo-only dedupe so repeated sign-ups do not stack conversations.
    final Conversation? existing = _conversations.values
        .where((Conversation c) => c.peerName == payer.name)
        .firstOrNull;
    if (existing != null) {
      return existing;
    }

    final DateTime now = DateTime.now();
    final int sequence = ++_conversationSequence;
    final String id = 'conv-deal-$sequence';
    final Conversation conversation = Conversation(
      id: id,
      peerName: payer.name,
      peerAvatarUrl: payer.avatarUrl,
      lastMessage: AppStrings.matchGreeting,
      lastMessageAt: now,
      unreadCount: 1,
      order: DateOrder(
        id: 'order-deal-$sequence',
        title: post.title,
        timeText: post.timeText,
        place: post.place,
        distanceKm: post.distanceKm,
        etaMinutes: math.max(5, (post.distanceKm * 3.5).round()),
        tipAmount: post.tipAmount,
        myStage: OrderStage.ready,
        peerStage: OrderStage.ready,
        isCompleted: false,
        postId: post.id,
      ),
    );
    final String fee = MoneyFormat.format(post.tipAmount);
    _conversations[id] = conversation;
    _messages[id] = <ChatMessage>[
      _event(
        id,
        now,
        OrderEventIcon.deal,
        AppStrings.dealTitle(post.title),
        AppStrings.dealSub(post.timeText, fee),
      ),
      _event(
        id,
        now,
        OrderEventIcon.escrow,
        AppStrings.escrowTitle(payer.name, fee),
        AppStrings.escrowSub,
        isHighlighted: true,
      ),
      _text(id, now, AppStrings.matchGreeting, false),
    ];
    _order.insert(0, id);
    _conversationsChanged.add(null);
    return conversation;
  }
}
