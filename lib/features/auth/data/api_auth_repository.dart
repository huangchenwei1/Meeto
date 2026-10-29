import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import 'auth_repository.dart';

/// Real OTP + JWT auth against the Meeto API.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<String?> requestOtp(String phone) async {
    final dynamic res = await _client.post(
      '/auth/otp/request',
      body: <String, dynamic>{'phone': phone},
    );
    return (res as Map<String, dynamic>)['devCode'] as String?;
  }

  @override
  Future<AuthResult> verifyOtp(String phone, String code) async {
    final Map<String, dynamic> res;
    try {
      res = await _client.post(
        '/auth/otp/verify',
        body: <String, dynamic>{'phone': phone, 'code': code},
      ) as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw const AuthException('Invalid code');
      }
      rethrow;
    }
    if (res['status'] == 'NEEDS_PROFILE') {
      return AuthResult.needsProfile(res['registrationToken'] as String);
    }
    _applySession(res);
    return const AuthResult.loggedIn();
  }

  @override
  Future<void> register({
    required String registrationToken,
    required String name,
    required String gender,
    required String role,
  }) async {
    final Map<String, dynamic> res = await _client.post(
      '/auth/register',
      body: <String, dynamic>{
        'registrationToken': registrationToken,
        'name': name,
        'gender': gender,
        'role': role,
      },
    ) as Map<String, dynamic>;
    _applySession(res);
  }

  void _applySession(Map<String, dynamic> res) {
    AuthSession.setTokens(
      access: res['accessToken'] as String,
      refresh: res['refreshToken'] as String,
    );
    final Map<String, dynamic> user = res['user'] as Map<String, dynamic>;
    AuthSession.setUser(
      id: user['id'] as String,
      name: user['name'] as String,
      avatarUrl: user['avatarUrl'] as String? ?? '',
      meta: user['meta'] as String? ?? '',
      gender: user['gender'] as String? ?? 'FEMALE',
      role: user['role'] as String?,
    );
  }
}
