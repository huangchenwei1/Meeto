/// Small value objects shared by profile models.
library;

/// A stat cell, e.g. ("36", "Dates completed").
class ProfileStat {
  const ProfileStat({required this.value, required this.label});

  final String value;
  final String label;
}

/// A labeled info row, e.g. ("Job", "Product manager").
class ProfileInfoItem {
  const ProfileInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

/// A review left by a past date partner.
class UserReview {
  const UserReview({
    required this.fromName,
    required this.avatarUrl,
    required this.text,
  });

  final String fromName;
  final String avatarUrl;
  final String text;
}
