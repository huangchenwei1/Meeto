import 'dart:async';
import 'dart:convert';

import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../community/models/activity_post.dart';
import '../../community/models/post_author.dart';
import '../models/live_order.dart';

/// Data source contract for orders (the escrow deal between the poster who
/// pays and the host who earns). API mode talks to the server
/// ([ApiOrdersRepository]); mock mode runs the same state machine locally
/// ([MockOrdersRepository]) so the demo build exercises identical UI flows.
abstract interface class OrdersRepository {
  Future<List<LiveOrder>> listMine();

  Future<LiveOrder> getOrder(String orderId);

  /// The caller's most recent non-cancelled order for [postId], if any
  /// (used to jump into the order room right after selecting a candidate).
  Future<LiveOrder?> findByPostId(String postId);

  /// The payer moves the service fee into escrow; the order goes ACTIVE.
  Future<LiveOrder> pay(String orderId);

  /// The host proposes (or re-proposes) the concrete plan: place, time
  /// and the itinerary. Each proposal lands in the chat as a plan card
  /// message; confirming makes it the order's effective place and time.
  Future<LiveOrder> proposePlan(
    String orderId, {
    required String place,
    double? placeLat,
    double? placeLng,
    required DateTime scheduledAt,
    required String note,
    required int durationMinutes,
  });

  /// The poster locks in the proposed plan.
  Future<LiveOrder> confirmPlan(String orderId);

  Future<LiveOrder> cancel(String orderId);

  /// The poster single-sidedly marks the activity as done; the escrow
  /// settles to the host immediately.
  Future<LiveOrder> complete(String orderId);

  Future<OrderMessage> sendMessage(String orderId, String text);

  Future<List<OrderMessage>> listMessages(String orderId, {String? afterId});
}

/// Local order state machine for the demo build. Mirrors the server rules:
/// AWAITING_PAYMENT -> (pay) ACTIVE -> (poster completes) COMPLETED, with
/// cancel as the side exit. Chat opens at payment and turns read-only
/// once the order settles or cancels.
class MockOrdersRepository implements OrdersRepository {
  MockOrdersRepository() {
    _seed();
  }

  final Map<String, _MockOrder> _orders = <String, _MockOrder>{};
  final List<String> _ids = <String>[];
  int _orderSequence = 0;
  int _messageSequence = 0;

  PostAuthor get _me => PostAuthor(
        id: AuthSession.currentUserId,
        name: AuthSession.currentUserName,
        avatarUrl: AuthSession.currentUserAvatarUrl,
        meta: AuthSession.currentUserMeta,
        isVerified: true,
      );

  // Demo hosts, aligned with the server seed cast.
  static const PostAuthor _liza = PostAuthor(
    id: 'host-203',
    name: 'Liza',
    avatarUrl: 'https://i.pravatar.cc/150?img=25',
    meta: 'Female \u00b7 25',
    isVerified: true,
  );
  static const PostAuthor _bianca = PostAuthor(
    id: 'host-201',
    name: 'Bianca',
    avatarUrl: 'https://i.pravatar.cc/150?img=44',
    meta: 'Female \u00b7 26',
    isVerified: true,
  );

  void _seed() {
    final DateTime now = DateTime.now();

    // An in-progress activity: Liza's movie plan is confirmed for Saturday.
    final _MockOrder active = _create(
      postId: 'post-003',
      earner: _liza,
      postTitle: 'Movie night with an actual plan',
      feePesos: 800,
      createdAt: now.subtract(const Duration(hours: 20)),
    )
      ..status = 'ACTIVE'
      ..planPlace = 'Power Plant Cinema, Rockwell'
      ..planAt = now.add(const Duration(days: 2))
      ..planNote = 'Early dinner at the food hall, then the 8pm screening'
      ..planDurationMinutes = 180
      ..planProposedAt = now.subtract(const Duration(hours: 18))
      ..planConfirmedAt = now.subtract(const Duration(hours: 17));
    _sayPlanCard(
      active,
      _liza.id,
      active.planPlace,
      active.planAt!,
      active.planNote,
      active.planDurationMinutes,
    );
    _say(active, _liza.id, 'Tickets reserved \u2014 see you Saturday!');

    // A finished one: Bianca's bookshop-cafe afternoon settled last week
    // (the activity behind moment-001; completed posts leave the wall).
    final _MockOrder done = _create(
      postId: 'post-000',
      earner: _bianca,
      postTitle: 'Coffee afternoon in a bookshop cafe',
      feePesos: 600,
      createdAt: now.subtract(const Duration(days: 7)),
    )
      ..status = 'COMPLETED'
      ..planPlace = 'Hidden cafe in a Legazpi bookshop'
      ..planAt = now.subtract(const Duration(days: 5))
      ..planProposedAt = now.subtract(const Duration(days: 7))
      ..planConfirmedAt = now.subtract(const Duration(days: 7))
      ..completedAt = now.subtract(const Duration(days: 5));
    _say(done, _bianca.id, 'That was a lovely afternoon, thank you!');
  }

  /// Called by the mock partner repository when the poster approves a
  /// candidate: creates the AWAITING_PAYMENT order exactly like the server
  /// does on selection.
  LiveOrder seedFromSelection(ActivityPost post, PostAuthor host) {
    final _MockOrder order = _create(
      postId: post.id,
      earner: host,
      postTitle: post.title,
      feePesos: post.budgetAmount,
      createdAt: DateTime.now(),
    );
    // Selection approves the plan card delivered at sign-up, mirroring
    // the server: the order starts with a confirmed plan and the card
    // already sits in the chat as its opening message.
    if (host.planPlace.isNotEmpty && host.planAt != null) {
      final DateTime now = DateTime.now();
      order
        ..planPlace = host.planPlace
        ..planAt = host.planAt
        ..planNote = host.proposal
        ..planDurationMinutes = host.planDurationMinutes
        ..planProposedAt = now
        ..planConfirmedAt = now;
      _sayPlanCard(order, host.id, host.planPlace, host.planAt!,
          host.proposal, host.planDurationMinutes);
    }
    return _toLive(order);
  }

  _MockOrder _create({
    required String postId,
    required PostAuthor earner,
    required String postTitle,
    required int feePesos,
    required DateTime createdAt,
  }) {
    final _MockOrder order = _MockOrder(
      id: 'order-${++_orderSequence}',
      postId: postId,
      payer: _me,
      earner: earner,
      feePesos: feePesos,
      postTitle: postTitle,
      createdAt: createdAt,
    );
    _orders[order.id] = order;
    _ids.insert(0, order.id);
    return order;
  }

  /// A plan card message: the frozen snapshot of the card at send time.
  void _sayPlanCard(
    _MockOrder order,
    String senderId,
    String place,
    DateTime scheduledAt,
    String note,
    int durationMinutes,
  ) {
    order.messages.add(
      OrderMessage(
        id: 'msg-${++_messageSequence}',
        senderId: senderId,
        kind: 'PLAN',
        text: jsonEncode(<String, Object>{
          'place': place,
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          'note': note,
          'durationMinutes': durationMinutes,
        }),
        createdAt: DateTime.now(),
      ),
    );
  }

  void _say(_MockOrder order, String senderId, String text) {
    order.messages.add(
      OrderMessage(
        id: 'msg-${++_messageSequence}',
        senderId: senderId,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
  }

  _MockOrder _of(String orderId) => _orders[orderId]!;

  LiveOrder _toLive(_MockOrder o) {
    final int net = ScenePricing.netEarnings(o.feePesos);
    final bool unlocked =
        o.status != 'AWAITING_PAYMENT' && o.status != 'CANCELLED';
    final bool planConfirmed = o.planConfirmedAt != null;
    return LiveOrder(
      id: o.id,
      postId: o.postId,
      payer: o.payer,
      earner: o.earner,
      status: o.status,
      feePesos: o.feePesos,
      commissionPesos: o.feePesos - net,
      netPesos: net,
      payerPhone: unlocked ? '+63 917 000 0100' : '',
      earnerPhone: unlocked ? '+63 917 000 0201' : '',
      postTitle: o.postTitle,
      scheduledAt: planConfirmed ? o.planAt : null,
      place: planConfirmed ? o.planPlace : '',
      placeLat: planConfirmed ? o.planLat : 0,
      placeLng: planConfirmed ? o.planLng : 0,
      planPlace: o.planPlace,
      planLat: o.planLat,
      planLng: o.planLng,
      planAt: o.planAt,
      planNote: o.planNote,
      planDurationMinutes: o.planDurationMinutes,
      planProposedAt: o.planProposedAt,
      planConfirmedAt: o.planConfirmedAt,
      completedAt: o.completedAt,
      createdAt: o.createdAt,
    );
  }

  @override
  Future<List<LiveOrder>> listMine() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _ids
        .map((String id) => _toLive(_orders[id]!))
        .toList(growable: false);
  }

  @override
  Future<LiveOrder> getOrder(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _toLive(_of(orderId));
  }

  @override
  Future<LiveOrder?> findByPostId(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    for (final String id in _ids) {
      final _MockOrder order = _orders[id]!;
      if (order.postId == postId && order.status != 'CANCELLED') {
        return _toLive(order);
      }
    }
    return null;
  }

  @override
  Future<LiveOrder> pay(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final _MockOrder order = _of(orderId)..status = 'ACTIVE';
    return _toLive(order);
  }

  @override
  Future<LiveOrder> proposePlan(
    String orderId, {
    required String place,
    double? placeLat,
    double? placeLng,
    required DateTime scheduledAt,
    required String note,
    required int durationMinutes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final _MockOrder order = _of(orderId)
      ..planPlace = place
      ..planLat = placeLat ?? 0
      ..planLng = placeLng ?? 0
      ..planAt = scheduledAt
      ..planNote = note
      ..planDurationMinutes = durationMinutes
      ..planProposedAt = DateTime.now()
      ..planConfirmedAt = null;
    _sayPlanCard(order, order.earner.id, place, scheduledAt, note,
        durationMinutes);
    return _toLive(order);
  }

  @override
  Future<LiveOrder> confirmPlan(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final _MockOrder order = _of(orderId)..planConfirmedAt = DateTime.now();
    return _toLive(order);
  }

  @override
  Future<LiveOrder> cancel(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final _MockOrder order = _of(orderId)..status = 'CANCELLED';
    return _toLive(order);
  }

  @override
  Future<LiveOrder> complete(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final _MockOrder order = _of(orderId)
      ..status = 'COMPLETED'
      ..completedAt = DateTime.now();
    return _toLive(order);
  }

  @override
  Future<OrderMessage> sendMessage(String orderId, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final _MockOrder order = _of(orderId);
    // Mirrors the server: the thread turns read-only once the activity
    // settles or cancels.
    if (order.status != 'ACTIVE') {
      throw const ApiException(409, 'CHAT_CLOSED');
    }
    _say(order, AuthSession.currentUserId, text);
    return order.messages.last;
  }

  @override
  Future<List<OrderMessage>> listMessages(
    String orderId, {
    String? afterId,
  }) async {
    final List<OrderMessage> all = _of(orderId).messages;
    if (afterId == null) {
      return List<OrderMessage>.unmodifiable(all);
    }
    final int index = all.indexWhere((OrderMessage m) => m.id == afterId);
    return List<OrderMessage>.unmodifiable(all.sublist(index + 1));
  }
}

/// Mutable internal state behind one mock order; converted to the
/// immutable [LiveOrder] on every read.
class _MockOrder {
  _MockOrder({
    required this.id,
    required this.postId,
    required this.payer,
    required this.earner,
    required this.feePesos,
    required this.postTitle,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final PostAuthor payer;
  final PostAuthor earner;
  final int feePesos;
  final String postTitle;
  final DateTime createdAt;

  String status = 'AWAITING_PAYMENT';
  String planPlace = '';
  double planLat = 0;
  double planLng = 0;
  DateTime? planAt;
  String planNote = '';
  int planDurationMinutes = 0;
  DateTime? planProposedAt;
  DateTime? planConfirmedAt;
  DateTime? completedAt;
  final List<OrderMessage> messages = <OrderMessage>[];
}
