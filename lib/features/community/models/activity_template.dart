/// A curated activity on the "hot activities" shelf. Picking one prefills
/// the publish flow (users post a request, hosts post a pitch), so posting
/// is "choose and confirm" rather than composing from a blank input. The
/// budget is not stored here — it is the platform scene fee, resolved from
/// pricing at display time.
class ActivityTemplate {
  const ActivityTemplate({
    required this.id,
    required this.sceneTag,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.durationLabel,
    required this.venueLabel,
    this.area = '',
  });

  factory ActivityTemplate.fromJson(Map<String, dynamic> json) {
    return ActivityTemplate(
      id: json['id'] as String,
      sceneTag: json['sceneTag'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      durationLabel: json['durationLabel'] as String? ?? '',
      venueLabel: json['venueLabel'] as String? ?? '',
      area: json['area'] as String? ?? '',
    );
  }

  final String id;
  final String sceneTag;
  final String title;
  final String description;
  final String imageUrl;

  /// Display label for the rough duration, e.g. "约 1.5 小时".
  final String durationLabel;

  /// Display label for the venue type, e.g. "咖啡馆".
  final String venueLabel;

  /// Rough city area the activity anchors to (e.g. "黎黄陂路"); matches
  /// the composer's area chips so launching prefills the post location.
  final String area;
}
