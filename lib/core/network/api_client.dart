import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../env/app_env.dart';
import '../session/auth_session.dart';

/// Error raised for non-2xx API responses.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;

  /// True when the server refused the action because the caller has not
  /// completed real-person verification; the UI should open the
  /// verification flow.
  bool get verificationRequired =>
      statusCode == 403 && message.contains('VERIFICATION_REQUIRED');
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON HTTP client for the Meeto API.
///
/// DEMO AUTH: requests authenticate via the `X-User-Id` header. [actAs]
/// lets demo director code impersonate other seeded users to play the
/// counterparty (see DEMO DIRECTOR notes); production uses a JWT for the
/// signed-in user only and removes [actAs].
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    String? actAs,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query?.isEmpty ?? true) ? null : query,
    );
    final http.Response response =
        await _http.get(uri, headers: _headers(actAs));
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body, String? actAs}) async {
    final http.Response response = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(actAs),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final http.Response response = await _http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(null),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final http.Response response = await _http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(null),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(response);
  }

  /// Uploads an image (multipart) and returns its root-relative URL.
  Future<String> uploadImage(List<int> bytes, String filename) async {
    final http.MultipartRequest request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
    request.headers.addAll(_headers(null)..remove('Content-Type'));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        // Without an explicit content type the part defaults to
        // application/octet-stream and the server mime whitelist rejects it.
        contentType: _imageMediaType(filename),
      ),
    );
    final http.Response response =
        await http.Response.fromStream(await _http.send(request));
    final Map<String, dynamic> json =
        _decode(response) as Map<String, dynamic>;
    return json['url'] as String;
  }

  Map<String, String> _headers(String? actAs) {
    // DEMO DIRECTOR impersonation uses the dev-only X-User-Id header; the
    // signed-in user authenticates with the JWT issued at login. The
    // X-User-Id fallback keeps pre-login requests (e.g. pricing) working.
    if (actAs != null) {
      return <String, String>{
        'Content-Type': 'application/json',
        'X-User-Id': actAs,
      };
    }
    final String? token = AuthSession.accessToken;
    if (token != null) {
      return <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'X-User-Id': AuthSession.currentUserId,
    };
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }
}

/// Converts server minor units (centavos) to the whole pesos the UI renders.
int minorToPesos(int minor) => (minor / 100).round();

MediaType _imageMediaType(String filename) {
  final String ext = filename.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'heic':
      return MediaType('image', 'heic');
    default:
      return MediaType('image', 'jpeg');
  }
}

/// Media URLs are stored root-relative (e.g. `/uploads/x.jpg`) so a future
/// host/CDN change never rewrites data; resolve them against the API host
/// for rendering. Absolute URLs (seed data) pass through unchanged.
String resolveMediaUrl(String url) =>
    url.startsWith('/') ? '${AppEnv.apiBaseUrl}$url' : url;
