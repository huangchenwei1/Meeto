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
  Future<List<LiveOrder>> listMine({bool all = false}) async {
    final List<dynamic> json =
        await _client.get(all ? '/orders?view=all' : '/orders')
            as List<dynamic>;
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
    // Full view: the freshly created order is still unpaid and would be
    // invisible in the conversations view.
    final List<LiveOrder> orders = await listMine(all: true);
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
  Future<LiveOrder> cancel(String orderId) => _action(orderId, 'cancel');

  @override
  Future<LiveOrder> start(String orderId, String code) async {
    return LiveOrder.fromJson(
      await _client.post(
        '/orders/$orderId/start',
        body: <String, dynamic>{'code': code},
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
