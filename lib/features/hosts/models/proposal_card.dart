import '../../../core/network/api_client.dart';

/// A host's activity pitch on the user home feed. The pitch is the
/// product; the host rides along as the signature line. Fee display is
/// resolved client-side from the live pricing config.
class ProposalCard {
  const ProposalCard({
    required this.id,
    required this.title,
    required this.sceneTag,
    this.imageUrl = '',
    required this.createdAt,
    required this.hostId,
    required this.hostName,
    required this.hostAvatarUrl,
    required this.hostMeta,
    required this.hostIsVerified,
    required this.hostCompletedActivities,
  });

  factory ProposalCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> host = json['host'] as Map<String, dynamic>;
    return ProposalCard(
      id: json['id'] as String,
      title: json['title'] as String,
      sceneTag: json['sceneTag'] as String,
      imageUrl: resolveMediaUrl(json['imageUrl'] as String? ?? ''),
      createdAt: DateTime.parse(json['createdAt'] as String),
      hostId: host['id'] as String,
      hostName: host['name'] as String,
      hostAvatarUrl: resolveMediaUrl(host['avatarUrl'] as String? ?? ''),
      hostMeta: host['meta'] as String? ?? '',
      hostIsVerified: host['isVerified'] as bool? ?? false,
      hostCompletedActivities: json['hostCompletedActivities'] as int? ?? 0,
    );
  }

  final String id;
  final String title;
  final String sceneTag;

  /// Cover photo; empty when the host posted a text-only pitch.
  final String imageUrl;

  final DateTime createdAt;
  final String hostId;
  final String hostName;
  final String hostAvatarUrl;
  final String hostMeta;
  final bool hostIsVerified;
  final int hostCompletedActivities;
}
