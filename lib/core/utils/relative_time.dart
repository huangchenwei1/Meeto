import '../constants/app_strings.dart';

/// Formats a [DateTime] as a short relative label, e.g. "5m ago".
extension RelativeTime on DateTime {
  String toRelativeLabel({DateTime? now}) {
    final Duration diff = (now ?? DateTime.now()).difference(this);
    if (diff.inMinutes < 1) {
      return AppStrings.justNow;
    }
    if (diff.inHours < 1) {
      return AppStrings.minutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return AppStrings.hoursAgo(diff.inHours);
    }
    return AppStrings.daysAgo(diff.inDays);
  }
}
