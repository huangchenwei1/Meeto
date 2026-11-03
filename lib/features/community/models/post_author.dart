/// Public info of a user on a post: the author, or a candidate in the
/// author's pool (then [proposal] carries their plan pitch).
class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.meta,
    required this.isVerified,
    this.proposal = '',
    this.planPlace = '',
    this.planAt,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String,
      meta: json['meta'] as String,
      isVerified: json['isVerified'] as bool,
      proposal: json['proposal'] as String? ?? '',
      planPlace: json['planPlace'] as String? ?? '',
      planAt: json['planAt'] == null
          ? null
          : DateTime.parse(json['planAt'] as String),
    );
  }

  final String id;
  final String name;
  final String avatarUrl;

  /// Short display meta, e.g. "Male · 27". In production derive it from
  /// structured gender/birthday fields.
  final String meta;

  final bool isVerified;

  /// The one-line plan pitch written at sign-up (candidates only).
  final String proposal;

  /// The structured plan card delivered at sign-up: venue...
  final String planPlace;

  /// ...and time. Selecting the candidate approves this plan.
  final DateTime? planAt;

  PostAuthor withProposal(
    String proposal, {
    String planPlace = '',
    DateTime? planAt,
  }) {
    return PostAuthor(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      meta: meta,
      isVerified: isVerified,
      proposal: proposal,
      planPlace: planPlace,
      planAt: planAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'meta': meta,
      'isVerified': isVerified,
    };
  }
}
