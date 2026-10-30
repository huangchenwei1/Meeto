import 'profile_parts.dart';

/// Full public profile of a user, shown on the user profile page.
class UserDetail {
  const UserDetail({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.meta,
    required this.isVerified,
    required this.city,
    required this.joinedText,
    required this.bio,
    required this.tags,
    this.hostScenes = const <String>[],
    required this.photos,
    required this.info,
    required this.stats,
    required this.reviews,
  });

  final String id;
  final String name;
  final String avatarUrl;

  /// Short display meta, e.g. "Male · 27".
  final String meta;

  final bool isVerified;
  final String city;
  final String joinedText;
  final String bio;
  final List<String> tags;

  /// Scene tags this user offers as a HOST (empty for USER accounts).
  final List<String> hostScenes;

  final List<String> photos;
  final List<ProfileInfoItem> info;
  final List<ProfileStat> stats;
  final List<UserReview> reviews;
}
