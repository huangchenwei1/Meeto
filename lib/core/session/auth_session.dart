/// In-memory auth session for the current app run.
///
/// Identity defaults to the demo persona (Andrea) so mock mode works with
/// zero setup; a successful login overwrites it. Tokens are memory-only for
/// now — production persists them in secure storage and restores the
/// session on launch.
abstract final class AuthSession {
  static String? accessToken;
  static String? refreshToken;

  static String currentUserId = 'user-100';
  static String currentUserName = 'Andrea';
  static String currentUserAvatarUrl = 'https://i.pravatar.cc/150?img=47';
  static String currentUserMeta = 'Female \u00b7 24';

  /// 'FEMALE' | 'MALE'. A profile fact and search preference only; money
  /// flow is driven by role, not gender.
  static String currentUserGender = 'FEMALE';

  static bool get isMale => currentUserGender == 'MALE';

  /// 'USER' | 'HOST', fixed at registration. USER posts activity requests
  /// and pays; HOST signs up to host them and earns. Drives which app
  /// shell (tab set) is shown.
  static String currentUserRole = 'USER';

  static bool get isHost => currentUserRole == 'HOST';

  static void setTokens({required String access, required String refresh}) {
    accessToken = access;
    refreshToken = refresh;
  }

  static void setUser({
    required String id,
    required String name,
    required String avatarUrl,
    required String meta,
    required String gender,
    String? role,
  }) {
    currentUserId = id;
    currentUserName = name;
    currentUserAvatarUrl = avatarUrl;
    currentUserMeta = meta;
    currentUserGender = gender;
    if (role != null) {
      currentUserRole = role;
    }
  }
}
