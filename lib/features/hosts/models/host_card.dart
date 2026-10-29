import '../../../core/network/api_client.dart';

/// Directory entry for a host: activity credentials first (completed
/// activities, recent plan pitches), looks second.
class HostCard {
  const HostCard({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.meta,
    required this.isVerified,
    required this.bio,
    required this.city,
    required this.tags,
    required this.completedActivities,
    required this.recentProposals,
  });

  factory HostCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> user = json['user'] as Map<String, dynamic>;
    return HostCard(
      id: user['id'] as String,
      name: user['name'] as String,
      avatarUrl: resolveMediaUrl(user['avatarUrl'] as String? ?? ''),
      meta: user['meta'] as String? ?? '',
      isVerified: user['isVerified'] as bool? ?? false,
      bio: user['bio'] as String? ?? '',
      city: user['city'] as String? ?? '',
      tags: (user['tags'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      completedActivities: json['completedActivities'] as int? ?? 0,
      recentProposals: (json['recentProposals'] as List<dynamic>? ??
              <dynamic>[])
          .cast<String>(),
    );
  }

  final String id;
  final String name;
  final String avatarUrl;
  final String meta;
  final bool isVerified;
  final String bio;
  final String city;
  final List<String> tags;
  final int completedActivities;

  /// The host's latest plan pitches, shown as hosting credentials.
  final List<String> recentProposals;
}

/// A direct invitation from a user to a host. PENDING until the host
/// accepts (which creates the order) or declines.
class InvitationRecord {
  const InvitationRecord({
    required this.id,
    required this.sceneTag,
    required this.note,
    required this.status,
    required this.fromName,
    required this.fromAvatarUrl,
    required this.fromMeta,
    required this.hostName,
    required this.orderId,
    required this.createdAt,
  });

  factory InvitationRecord.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> from = json['from'] as Map<String, dynamic>;
    final Map<String, dynamic> host = json['host'] as Map<String, dynamic>;
    return InvitationRecord(
      id: json['id'] as String,
      sceneTag: json['sceneTag'] as String,
      note: json['note'] as String? ?? '',
      status: json['status'] as String,
      fromName: from['name'] as String,
      fromAvatarUrl: resolveMediaUrl(from['avatarUrl'] as String? ?? ''),
      fromMeta: from['meta'] as String? ?? '',
      hostName: host['name'] as String,
      orderId: json['orderId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String sceneTag;
  final String note;

  /// PENDING | ACCEPTED | DECLINED
  final String status;
  final String fromName;
  final String fromAvatarUrl;
  final String fromMeta;
  final String hostName;
  final String orderId;
  final DateTime createdAt;

  bool get isPending => status == 'PENDING';
}
