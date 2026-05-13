import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodeSuggestion {
  GeocodeSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  final String displayName;
  final double lat;
  final double lng;

  factory GeocodeSuggestion.fromJson(Map<String, dynamic> json) {
    return GeocodeSuggestion(
      displayName: json['display_name'] as String? ?? 'Direccion',
      lat: double.tryParse('${json['lat']}') ?? 0,
      lng: double.tryParse('${json['lon']}') ?? 0,
    );
  }
}

class GeocodingClient {
  Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'jsonv2',
      'accept-language': 'es',
      'zoom': '18',
    });

    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'Karryt Flutter/1.0 (logistics app)',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final displayName = data['display_name'];
    if (displayName is String && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    return null;
  }

  Future<List<GeocodeSuggestion>> searchAddresses(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': normalizedQuery,
      'format': 'jsonv2',
      'accept-language': 'es',
      'addressdetails': '1',
      'limit': '6',
    });

    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'Karryt Flutter/1.0 (logistics app)',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map>()
        .map((item) => GeocodeSuggestion.fromJson(item.cast<String, dynamic>()))
        .toList();
  }
}

