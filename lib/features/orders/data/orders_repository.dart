import 'dart:async';

import '../../../core/constants/scene_pricing.dart';
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

  /// The host proposes (or re-proposes) the concrete plan.
  Future<LiveOrder> proposePlan(
    String orderId, {
    required String place,
    double? placeLat,
    double? placeLng,
    required DateTime scheduledAt,
  });

  /// The poster locks in the proposed plan.
  Future<LiveOrder> confirmPlan(String orderId);

  Future<LiveOrder> cancel(String orderId);

  Future<LiveOrder> dispute(String orderId);

  /// Shares the caller's current location (distance readout for the peer).
  Future<LiveOrder> updateLocation(
    String orderId, {
    required double lat,
    required double lng,
  });

  /// One-tap meet confirmation with the GPS fix taken at tap time.
  Future<LiveOrder> confirmMeet(
    String orderId, {
    required double lat,
    required double lng,
  });

  Future<OrderMessage> sendMessage(String orderId, String text);

  Future<List<OrderMessage>> listMessages(String orderId, {String? afterId});
}

/// Local order state machine for the demo build. Mirrors the server rules:
/// AWAITING_PAYMENT -> (pay) ACTIVE -> (both meet) MET -> (settle delay)
/// COMPLETED, with cancel/dispute side exits. The peer's reactions are
/// simulated with short timers.
class MockOrdersRepository implements OrdersRepository {
  MockOrdersRepository() {
    _seed();
  }

  static const Duration _settleDelay = Duration(minutes: 1);

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
      ..planProposedAt = now.subtract(const Duration(hours: 18))
      ..planConfirmedAt = now.subtract(const Duration(hours: 17));
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
      ..payerMetAt = now.subtract(const Duration(days: 5))
      ..earnerMetAt = now.subtract(const Duration(days: 5))
      ..metAt = now.subtract(const Duration(days: 5))
      ..settleAt = now.subtract(const Duration(days: 5));
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
      place: post.place,
      scheduledAt: null,
    );
    return _toLive(order);
  }

  _MockOrder _create({
    required String postId,
    required PostAuthor earner,
    required String postTitle,
    required int feePesos,
    required DateTime createdAt,
    String place = '',
    DateTime? scheduledAt,
  }) {
    final _MockOrder order = _MockOrder(
      id: 'order-${++_orderSequence}',
      postId: postId,
      payer: _me,
      earner: earner,
      feePesos: feePesos,
      postTitle: postTitle,
      place: place,
      scheduledAt: scheduledAt,
      createdAt: createdAt,
    );
    _orders[order.id] = order;
    _ids.insert(0, order.id);
    return order;
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
      distanceKm: null,
      payerLat: o.payerLat,
      payerLng: o.payerLng,
      earnerLat: o.earnerLat,
      earnerLng: o.earnerLng,
      postTitle: o.postTitle,
      scheduledAt: o.planConfirmedAt != null ? o.planAt : o.scheduledAt,
      place: o.planConfirmedAt != null && o.planPlace.isNotEmpty
          ? o.planPlace
          : o.place,
      placeLat: o.planLat,
      placeLng: o.planLng,
      planPlace: o.planPlace,
      planLat: o.planLat,
      planLng: o.planLng,
      planAt: o.planAt,
      planProposedAt: o.planProposedAt,
      planConfirmedAt: o.planConfirmedAt,
      payerMetAt: o.payerMetAt,
      earnerMetAt: o.earnerMetAt,
      metAt: o.metAt,
      settleAt: o.settleAt,
      disputed: o.disputed,
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
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final _MockOrder order = _of(orderId)
      ..planPlace = place
      ..planLat = placeLat ?? 0
      ..planLng = placeLng ?? 0
      ..planAt = scheduledAt
      ..planProposedAt = DateTime.now()
      ..planConfirmedAt = null;
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
  Future<LiveOrder> dispute(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final _MockOrder order = _of(orderId)
      ..disputed = true
      ..status = 'DISPUTED';
    return _toLive(order);
  }

  @override
  Future<LiveOrder> updateLocation(
    String orderId, {
    required double lat,
    required double lng,
  }) async {
    final _MockOrder order = _of(orderId);
    if (order.payer.id == AuthSession.currentUserId) {
      order
        ..payerLat = lat
        ..payerLng = lng;
    } else {
      order
        ..earnerLat = lat
        ..earnerLng = lng;
    }
    return _toLive(order);
  }

  @override
  Future<LiveOrder> confirmMeet(
    String orderId, {
    required double lat,
    required double lng,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final _MockOrder order = _of(orderId);
    final bool iAmPayer = order.payer.id == AuthSession.currentUserId;
    final DateTime now = DateTime.now();
    if (iAmPayer) {
      order.payerMetAt = now;
    } else {
      order.earnerMetAt = now;
    }
    // Simulated peer: confirms shortly after me, then the escrow settles
    // after the demo delay (server behavior in miniature).
    Timer(const Duration(milliseconds: 1500), () {
      if (iAmPayer) {
        order.earnerMetAt ??= DateTime.now();
      } else {
        order.payerMetAt ??= DateTime.now();
      }
      _settleIfMet(order);
    });
    _settleIfMet(order);
    return _toLive(order);
  }

  void _settleIfMet(_MockOrder order) {
    if (order.payerMetAt == null ||
        order.earnerMetAt == null ||
        order.metAt != null) {
      return;
    }
    order
      ..status = 'MET'
      ..metAt = DateTime.now()
      ..settleAt = DateTime.now().add(_settleDelay);
    Timer(_settleDelay, () {
      if (order.status == 'MET' && !order.disputed) {
        order.status = 'COMPLETED';
      }
    });
  }

  @override
  Future<OrderMessage> sendMessage(String orderId, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final _MockOrder order = _of(orderId);
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
    required this.place,
    required this.scheduledAt,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final PostAuthor payer;
  final PostAuthor earner;
  final int feePesos;
  final String postTitle;
  final String place;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  String status = 'AWAITING_PAYMENT';
  String planPlace = '';
  double planLat = 0;
  double planLng = 0;
  DateTime? planAt;
  DateTime? planProposedAt;
  DateTime? planConfirmedAt;
  DateTime? payerMetAt;
  DateTime? earnerMetAt;
  DateTime? metAt;
  DateTime? settleAt;
  bool disputed = false;
  double? payerLat;
  double? payerLng;
  double? earnerLat;
  double? earnerLng;
  final List<OrderMessage> messages = <OrderMessage>[];
}
