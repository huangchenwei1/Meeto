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
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String,
      meta: json['meta'] as String,
      isVerified: json['isVerified'] as bool,
      proposal: json['proposal'] as String? ?? '',
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

  PostAuthor withProposal(String proposal) {
    return PostAuthor(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      meta: meta,
      isVerified: isVerified,
      proposal: proposal,
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
