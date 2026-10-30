import '../constants/app_strings.dart';

/// Compact relative timestamp for list rows, e.g. "Just now", "5m ago",
/// "2h ago", "3d ago".
String formatTimeAgo(DateTime time) {
  final Duration diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) {
    return AppStrings.timeJustNow;
  }
  if (diff.inHours < 1) {
    return AppStrings.timeMinutesAgo(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return AppStrings.timeHoursAgo(diff.inHours);
  }
  return AppStrings.timeDaysAgo(diff.inDays);
}
