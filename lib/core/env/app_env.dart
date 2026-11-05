import 'dart:io';

import 'package:flutter/foundation.dart';

/// Build-time environment switches.
///
/// Data source resolution, in order:
/// - `--dart-define=MEETO_USE_MOCK=true` forces the in-memory mocks.
/// - `flutter test` always runs on mocks (FLUTTER_TEST is predefined).
/// - `--dart-define=MEETO_API_BASE_URL=...` points at an explicit server.
/// - Otherwise debug builds default to the local dev server, so a plain
///   `flutter run` behaves exactly like the deployed build; release
///   builds without an explicit server fall back to mocks (standalone
///   demo with zero infrastructure).
abstract final class AppEnv {
  static const bool _forceMock = bool.fromEnvironment('MEETO_USE_MOCK');

  /// `flutter test` exports FLUTTER_TEST into the test process
  /// environment (it is not a compile-time define on this toolchain).
  static final bool _isFlutterTest =
      Platform.environment.containsKey('FLUTTER_TEST');

  static const String _definedBaseUrl = String.fromEnvironment(
    'MEETO_API_BASE_URL',
  );

  /// The iOS simulator shares the host loopback, so this reaches the dev
  /// server started from the repo.
  static const String _debugDefaultBaseUrl = 'http://localhost:3000';

  static String get apiBaseUrl {
    if (_forceMock || _isFlutterTest) {
      return '';
    }
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    return kDebugMode ? _debugDefaultBaseUrl : '';
  }

  static bool get useRemoteApi => apiBaseUrl.isNotEmpty;
}
