import '../../../core/constants/scene_images.dart';
import '../../../core/network/api_client.dart';

/// A host's activity pitch on the user home feed. The pitch is the
/// product; the host rides along as the signature line. Fee display is
/// resolved client-side from the live pricing config.
class ProposalCard {
  const ProposalCard({
    required this.id,
    required this.title,
    this.description = '',
    required this.sceneTag,
    this.imageUrl = '',
    this.area = '',
    this.timeSlot = '',
    this.budgetAmount = 0,
    required this.createdAt,
    required this.hostId,
    required this.hostName,
    required this.hostAvatarUrl,
    required this.hostMeta,
    this.hostCity = '',
    required this.hostIsVerified,
    required this.hostCompletedActivities,
  });

  factory ProposalCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> host = json['host'] as Map<String, dynamic>;
    return ProposalCard(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      sceneTag: json['sceneTag'] as String,
      imageUrl: resolveMediaUrl(json['imageUrl'] as String? ?? ''),
      area: json['area'] as String? ?? '',
      timeSlot: json['timeSlot'] as String? ?? '',
      budgetAmount: minorToPesos(json['budgetMinor'] as int? ?? 0),
      createdAt: DateTime.parse(json['createdAt'] as String),
      hostId: host['id'] as String,
      hostName: host['name'] as String,
      hostAvatarUrl: resolveMediaUrl(host['avatarUrl'] as String? ?? ''),
      hostMeta: host['meta'] as String? ?? '',
      hostCity: host['city'] as String? ?? '',
      hostIsVerified: host['isVerified'] as bool? ?? false,
      hostCompletedActivities: json['hostCompletedActivities'] as int? ?? 0,
    );
  }

  final String id;
  final String title;

  /// Optional elaboration, mirrors demand posts.
  final String description;

  final String sceneTag;

  /// Cover photo; empty when the host posted a text-only pitch.
  final String imageUrl;

  /// What the feed shows: the uploaded cover, or the platform default
  /// image for the scene when the pitch was posted without a photo.
  String get coverImageUrl =>
      imageUrl.isNotEmpty ? imageUrl : SceneImages.forScene(sceneTag);

  /// Rough area of the pitch (e.g. "Poblacion"); the exact venue comes
  /// later via the order plan flow.
  final String area;

  /// Fuzzy time window key (e.g. "weekend"), same options as demand posts.
  final String timeSlot;

  /// The budget tier the host picked at publish time (whole pesos):
  /// inviting from this pitch pays exactly this.
  final int budgetAmount;

  final DateTime createdAt;
  final String hostId;
  final String hostName;
  final String hostAvatarUrl;
  final String hostMeta;
  final String hostCity;
  final bool hostIsVerified;
  final int hostCompletedActivities;

  /// "Manila · Poblacion" — whichever parts exist.
  String get locationLine => <String>[
        if (hostCity.isNotEmpty) hostCity,
        if (area.isNotEmpty) area,
      ].join(' \u00b7 ');
}
