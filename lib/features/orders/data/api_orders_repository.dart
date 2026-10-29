import '../../../core/network/api_client.dart';
import '../models/live_order.dart';
import 'orders_repository.dart';

/// Real order operations against the Meeto API, used in API mode where both
/// sides act from their own devices. Clients poll for peer-side changes
/// (interim transport; a push channel replaces polling with the IM work).
class ApiOrdersRepository implements OrdersRepository {
  ApiOrdersRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<LiveOrder>> listMine() async {
    final List<dynamic> json = await _client.get('/orders') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(LiveOrder.fromJson)
        .toList(growable: false);
  }

  @override
  Future<LiveOrder> getOrder(String orderId) async {
    return LiveOrder.fromJson(
      await _client.get('/orders/$orderId') as Map<String, dynamic>,
    );
  }

  @override
  Future<LiveOrder?> findByPostId(String postId) async {
    final List<LiveOrder> orders = await listMine();
    for (final LiveOrder order in orders) {
      if (order.postId == postId && order.status != 'CANCELLED') {
        return order;
      }
    }
    return null;
  }

  @override
  Future<LiveOrder> pay(String orderId) => _action(orderId, 'payment');

  @override
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

  @override
  Future<LiveOrder> confirmPlan(String orderId) =>
      _action(orderId, 'plan/confirm');

  @override
  Future<LiveOrder> cancel(String orderId) => _action(orderId, 'cancel');

  @override
  Future<LiveOrder> dispute(String orderId) => _action(orderId, 'dispute');

  @override
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

  @override
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

  @override
  Future<OrderMessage> sendMessage(String orderId, String text) async {
    return OrderMessage.fromJson(
      await _client.post(
        '/orders/$orderId/messages',
        body: <String, dynamic>{'text': text},
      ) as Map<String, dynamic>,
    );
  }

  @override
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
