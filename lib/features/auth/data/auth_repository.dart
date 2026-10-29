import '../../../core/session/auth_session.dart';

enum AuthStatus { loggedIn, needsProfile }

/// Outcome of an OTP verification: either a completed login or a pending
/// registration carrying the token that authorizes profile creation.
class AuthResult {
  const AuthResult.loggedIn() : status = AuthStatus.loggedIn, registrationToken = null;

  const AuthResult.needsProfile(this.registrationToken)
      : status = AuthStatus.needsProfile;

  final AuthStatus status;
  final String? registrationToken;
}

abstract interface class AuthRepository {
  /// Sends an OTP to [phone]. Returns the dev code when the backend (or
  /// mock) exposes one so the UI can hint it during demos.
  Future<String?> requestOtp(String phone);

  /// Verifies the OTP. On success the session is populated (loggedIn) or a
  /// registration token is returned (needsProfile). Throws on a bad code.
  Future<AuthResult> verifyOtp(String phone, String code);

  /// Completes registration for a verified new phone and logs in.
  /// [role] is 'USER' or 'HOST', fixed for the account's lifetime.
  Future<void> register({
    required String registrationToken,
    required String name,
    required String gender,
    required String role,
  });
}

/// Standalone demo auth: any phone logs in as the demo persona with the
/// fixed code. No network involved.
class MockAuthRepository implements AuthRepository {
  static const String _demoCode = '123456';

  @override
  Future<String?> requestOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _demoCode;
  }

  @override
  Future<AuthResult> verifyOtp(String phone, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (code != _demoCode) {
      throw const AuthException('Invalid code');
    }
    // Mock mode always signs in as the default demo persona already present
    // in AuthSession; nothing else to update.
    return const AuthResult.loggedIn();
  }

  @override
  Future<void> register({
    required String registrationToken,
    required String name,
    required String gender,
    required String role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    AuthSession.setUser(
      id: AuthSession.currentUserId,
      name: name,
      avatarUrl: AuthSession.currentUserAvatarUrl,
      meta: gender == 'FEMALE' ? 'Female' : 'Male',
      gender: gender,
      role: role,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
