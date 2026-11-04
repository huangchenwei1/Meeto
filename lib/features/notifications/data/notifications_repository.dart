import '../../../core/network/api_client.dart';

/// One in-app notification as served by the API.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    required this.actorAvatarUrl,
    required this.postId,
    required this.orderId,
    this.proposalId = '',
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      actorName: json['actorName'] as String? ?? '',
      actorAvatarUrl:
          resolveMediaUrl(json['actorAvatarUrl'] as String? ?? ''),
      postId: json['postId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      proposalId: json['proposalId'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String type; // NEW_APPLICANT | SELECTED | ORDER_PAID | ORDER_CANCELLED
  final String actorName;
  final String actorAvatarUrl;
  final String postId;
  final String orderId;

  /// Deep link for proposal-scoped events (e.g. a new invitation).
  final String proposalId;
  final bool isRead;
  final DateTime createdAt;
}

/// In-app notifications. Push delivery (APNs/FCM) later reuses the same
/// backend data.
abstract interface class NotificationsRepository {
  Future<List<AppNotification>> list();
  Future<int> unreadCount();
  Future<void> markAllRead();
}

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<AppNotification>> list() async {
    final List<dynamic> json =
        await _client.get('/notifications') as List<dynamic>;
    return json
        .map((dynamic e) =>
            AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<int> unreadCount() async {
    final Map<String, dynamic> json =
        await _client.get('/notifications/unread-count')
            as Map<String, dynamic>;
    return json['count'] as int;
  }

  @override
  Future<void> markAllRead() async {
    await _client.post('/notifications/read');
  }
}

/// The demo build has no notification sources; the inbox stays empty.
class MockNotificationsRepository implements NotificationsRepository {
  @override
  Future<List<AppNotification>> list() async => const <AppNotification>[];

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> markAllRead() async {}
}
