import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import 'api_auth_repository.dart';
import 'auth_repository.dart';

/// Single place that picks the auth backend for the current build mode.
AuthRepository createAuthRepository() {
  return AppEnv.useRemoteApi
      ? ApiAuthRepository(ApiClient(baseUrl: AppEnv.apiBaseUrl))
      : MockAuthRepository();
}
