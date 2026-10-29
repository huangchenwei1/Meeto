import '../../../core/network/api_client.dart';
import '../models/live_order.dart';

/// Real order operations against the Meeto API, used in API mode where both
/// sides act from their own devices. Clients poll for peer-side changes
/// (interim transport; a push channel replaces polling with the IM work).
class OrdersRepository {
  OrdersRepository(this._client);

  final ApiClient _client;

  Future<List<LiveOrder>> listMine() async {
    final List<dynamic> json = await _client.get('/orders') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(LiveOrder.fromJson)
        .toList(growable: false);
  }

  Future<LiveOrder> getOrder(String orderId) async {
    return LiveOrder.fromJson(
      await _client.get('/orders/$orderId') as Map<String, dynamic>,
    );
  }

  /// Finds the caller's most recent order for [postId], if any (used to jump
  /// into the order room right after selecting a candidate).
  Future<LiveOrder?> findByPostId(String postId) async {
    final List<LiveOrder> orders = await listMine();
    for (final LiveOrder order in orders) {
      if (order.postId == postId &&
          order.status != 'CANCELLED') {
        return order;
      }
    }
    return null;
  }

  Future<LiveOrder> pay(String orderId) => _action(orderId, 'payment');

  /// The host proposes (or re-proposes) the concrete plan.
  Future<LiveOrder> proposePlan(
    String orderId, {
    required String place,
    double? placeLat,
    double? placeLng,
    required DateTime scheduledAt,
  }) async {
    return LiveOrder.fromJson(
      await _client.post(
        '/orders/$orderId/plan',
        body: <String, dynamic>{
          'place': place,
          'placeLat': ?placeLat,
          'placeLng': ?placeLng,
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        },
      ) as Map<String, dynamic>,
    );
  }

  /// The poster locks in the proposed plan.
  Future<LiveOrder> confirmPlan(String orderId) =>
      _action(orderId, 'plan/confirm');

  Future<LiveOrder> cancel(String orderId) => _action(orderId, 'cancel');

  Future<LiveOrder> dispute(String orderId) => _action(orderId, 'dispute');

  /// Shares the caller's current location (distance readout for the peer).
  Future<LiveOrder> updateLocation(
    String orderId, {
    required double lat,
    required double lng,
  }) async {
    return LiveOrder.fromJson(
      await _client.post(
        '/orders/$orderId/location',
        body: <String, dynamic>{'lat': lat, 'lng': lng},
      ) as Map<String, dynamic>,
    );
  }

  /// One-tap meet confirmation with the GPS fix taken at tap time.
  Future<LiveOrder> confirmMeet(
    String orderId, {
    required double lat,
    required double lng,
  }) async {
    return LiveOrder.fromJson(
      await _client.post(
        '/orders/$orderId/meet',
        body: <String, dynamic>{'lat': lat, 'lng': lng},
      ) as Map<String, dynamic>,
    );
  }

  Future<OrderMessage> sendMessage(String orderId, String text) async {
    return OrderMessage.fromJson(
      await _client.post(
        '/orders/$orderId/messages',
        body: <String, dynamic>{'text': text},
      ) as Map<String, dynamic>,
    );
  }

  Future<List<OrderMessage>> listMessages(
    String orderId, {
    String? afterId,
  }) async {
    final List<dynamic> json = await _client.get(
      '/orders/$orderId/messages',
      query: afterId == null ? null : <String, String>{'afterId': afterId},
    ) as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(OrderMessage.fromJson)
        .toList(growable: false);
  }

  Future<LiveOrder> _action(String orderId, String action) async {
    return LiveOrder.fromJson(
      await _client.post('/orders/$orderId/$action') as Map<String, dynamic>,
    );
  }
}
