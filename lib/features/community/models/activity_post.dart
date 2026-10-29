import 'post_author.dart';

/// An activity post on the community wall.
///
/// BUSINESS RULES:
/// - DEMAND: a user-side activity request. Hosts sign up with a plan pitch;
///   the poster approves one plan, pays the platform-set [budgetAmount] into
///   escrow, and the selected host earns it minus the commission.
/// - MOMENT: a non-transactional photo/text recap of a completed activity.
/// - The wall shows waiting and in-progress activities; [selectedHost]
///   carries the attribution once a plan was approved.
class ActivityPost {
  const ActivityPost({
    required this.id,
    this.type = 'DEMAND',
    required this.sceneTag,
    required this.title,
    required this.description,
    required this.detail,
    required this.timeText,
    required this.place,
    this.placeLat = 0,
    this.placeLng = 0,
    required this.distanceKm,
    required this.signedCount,
    required this.imageUrl,
    this.images = const <String>[],
    required this.author,
    required this.createdAt,
    required this.budgetAmount,
    this.hasApplied = false,
    this.status = 'OPEN',
    this.selectedHost,
  });

  factory ActivityPost.fromJson(Map<String, dynamic> json) {
    return ActivityPost(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'DEMAND',
      sceneTag: json['sceneTag'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      detail: json['detail'] as String,
      timeText: json['timeText'] as String,
      place: json['place'] as String,
      placeLat: (json['placeLat'] as num?)?.toDouble() ?? 0,
      placeLng: (json['placeLng'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      signedCount: json['signedCount'] as int,
      imageUrl: json['imageUrl'] as String,
      images:
          (json['images'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      budgetAmount: json['budgetAmount'] as int,
      hasApplied: json['hasApplied'] as bool? ?? false,
      status: json['status'] as String? ?? 'OPEN',
      selectedHost: json['selectedHost'] == null
          ? null
          : PostAuthor.fromJson(json['selectedHost'] as Map<String, dynamic>),
    );
  }

  final String id;

  /// DEMAND (transactional activity request) | MOMENT (community recap).
  final String type;

  bool get isMoment => type == 'MOMENT';

  /// Scene category label, e.g. "Coffee", "Dinner".
  final String sceneTag;

  final String title;

  /// One-line summary shown on the feed card.
  final String description;

  /// Full description shown on the detail page.
  final String detail;

  /// Human-readable schedule, e.g. "Saturday 2:00 PM · ~3 hours".
  final String timeText;

  final String place;

  /// Structured venue coordinates (zeros mean the poster typed a free-form
  /// place, so no map/distance is available).
  final double placeLat;
  final double placeLng;

  /// Whether the venue has real coordinates.
  bool get hasVenueLocation => placeLat != 0 || placeLng != 0;

  final double distanceKm;

  /// Number of candidates who signed up so far.
  final int signedCount;

  /// Cover photo uploaded by the poster.
  final String imageUrl;

  /// Photo set for MOMENT posts (empty for demand posts).
  final List<String> images;

  final PostAuthor author;
  final DateTime createdAt;

  /// Platform-set service fee (whole pesos) for this scene. Paid by the
  /// poster on match; the host earns it minus the platform commission.
  final int budgetAmount;

  /// Whether the current user has already signed up as a candidate.
  final bool hasApplied;

  /// OPEN | PENDING_PAYMENT | MATCHED | COMPLETED | CANCELLED.
  final String status;

  /// The host whose plan was approved; null while the post is still open.
  final PostAuthor? selectedHost;

  /// Whether a host already took the activity (any post-selection status).
  bool get hasHost => selectedHost != null;

  String get distanceLabel {
    final bool isWhole = distanceKm == distanceKm.roundToDouble();
    return isWhole ? distanceKm.toInt().toString() : distanceKm.toString();
  }

  ActivityPost copyWith({
    int? signedCount,
    bool? hasApplied,
    String? status,
    PostAuthor? selectedHost,
  }) {
    return ActivityPost(
      id: id,
      type: type,
      sceneTag: sceneTag,
      title: title,
      description: description,
      detail: detail,
      timeText: timeText,
      place: place,
      placeLat: placeLat,
      placeLng: placeLng,
      distanceKm: distanceKm,
      signedCount: signedCount ?? this.signedCount,
      imageUrl: imageUrl,
      images: images,
      author: author,
      createdAt: createdAt,
      budgetAmount: budgetAmount,
      hasApplied: hasApplied ?? this.hasApplied,
      status: status ?? this.status,
      selectedHost: selectedHost ?? this.selectedHost,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sceneTag': sceneTag,
      'title': title,
      'description': description,
      'detail': detail,
      'timeText': timeText,
      'place': place,
      'distanceKm': distanceKm,
      'signedCount': signedCount,
      'imageUrl': imageUrl,
      'author': author.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'budgetAmount': budgetAmount,
      'hasApplied': hasApplied,
    };
  }
}
