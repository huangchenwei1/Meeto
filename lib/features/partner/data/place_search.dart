import 'dart:convert';

import 'package:http/http.dart' as http;

/// A venue candidate returned by the place search.
class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
}

/// Free-tier venue search backed by OpenStreetMap Nominatim (no API key).
/// Swapping to Google Places later only touches this class.
class PlaceSearch {
  static const String _endpoint = 'https://nominatim.openstreetmap.org/search';

  /// Roughly city-sized box (~0.15 degrees, about 16 km) around the caller's
  /// location used to keep suggestions local.
  static const double _cityBoxDegrees = 0.15;

  /// Searches venues; when the caller's location is known the results are
  /// restricted to the surrounding city-sized area first, widening to the
  /// whole country when nothing local matches.
  Future<List<PlaceResult>> search(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    if (nearLat != null && nearLng != null) {
      final List<PlaceResult> local = await _request(
        query,
        viewbox: <double>[
          nearLng - _cityBoxDegrees,
          nearLat + _cityBoxDegrees,
          nearLng + _cityBoxDegrees,
          nearLat - _cityBoxDegrees,
        ],
      );
      if (local.isNotEmpty) {
        return local;
      }
    }
    return _request(query);
  }

  Future<List<PlaceResult>> _request(
    String query, {
    List<double>? viewbox,
  }) async {
    final Uri uri = Uri.parse(_endpoint).replace(
      queryParameters: <String, String>{
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': 'ph',
        'addressdetails': '0',
        if (viewbox != null) ...<String, String>{
          'viewbox': viewbox.join(','),
          'bounded': '1',
        },
      },
    );
    final http.Response response = await http.get(
      uri,
      // Nominatim usage policy requires an identifying user agent.
      headers: <String, String>{'User-Agent': 'Meeto/0.1 (dev)'},
    );
    if (response.statusCode != 200) {
      return const <PlaceResult>[];
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json.cast<Map<String, dynamic>>().map((Map<String, dynamic> item) {
      final String displayName = item['display_name'] as String? ?? '';
      final String name = (item['name'] as String?)?.isNotEmpty ?? false
          ? item['name'] as String
          : displayName.split(',').first.trim();
      return PlaceResult(
        name: name,
        address: displayName,
        lat: double.parse(item['lat'] as String),
        lng: double.parse(item['lon'] as String),
      );
    }).toList(growable: false);
  }
}
