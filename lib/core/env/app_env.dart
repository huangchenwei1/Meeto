/// Build-time environment switches.
///
/// Run against the real backend with:
///   flutter run --dart-define=MEETO_API_BASE_URL=http://localhost:3000
///
/// Without the define, the app runs fully on in-memory mocks (standalone
/// demo mode) — same UI, zero infrastructure.
abstract final class AppEnv {
  static const String apiBaseUrl = String.fromEnvironment(
    'MEETO_API_BASE_URL',
  );

  static bool get useRemoteApi => apiBaseUrl.isNotEmpty;
}
