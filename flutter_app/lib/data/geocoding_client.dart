import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class GeocodeSuggestion {
  GeocodeSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.placeId,
    this.primaryText,
    this.secondaryText,
    this.provider = 'nominatim',
  });

  final String displayName;
  final double lat;
  final double lng;
  final String? placeId;
  final String? primaryText;
  final String? secondaryText;
  final String provider;

  bool get isGooglePrediction =>
      provider == 'google' && placeId != null && placeId!.trim().isNotEmpty;

  bool get hasCoordinates => lat != 0 || lng != 0;

  factory GeocodeSuggestion.fromJson(Map<String, dynamic> json) {
    return GeocodeSuggestion(
      displayName: json['display_name'] as String? ?? 'Direccion',
      lat: double.tryParse('${json['lat']}') ?? 0,
      lng: double.tryParse('${json['lon']}') ?? 0,
      placeId: json['place_id'] as String?,
      primaryText: json['primary_text'] as String?,
      secondaryText: json['secondary_text'] as String?,
      provider: json['provider'] as String? ??
          ((json['place_id'] as String?)?.isNotEmpty == true
              ? 'google'
              : 'nominatim'),
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

  Future<List<GeocodeSuggestion>> searchAddresses(
    String query, {
    double? biasLat,
    double? biasLng,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final queryParameters = <String, String>{
      'q': normalizedQuery,
      'format': 'jsonv2',
      'accept-language': 'es',
      'addressdetails': '1',
      'limit': '8',
      'countrycodes': 'mx',
      'dedupe': '1',
    };

    if (biasLat != null && biasLng != null) {
      const latDelta = 0.22;
      final lngDelta = latDelta /
          math.max(0.3, math.cos(biasLat * math.pi / 180).abs());

      queryParameters['viewbox'] =
          '${(biasLng - lngDelta).toStringAsFixed(4)},${(biasLat + latDelta).toStringAsFixed(4)},${(biasLng + lngDelta).toStringAsFixed(4)},${(biasLat - latDelta).toStringAsFixed(4)}';
    }

    final uri =
        Uri.https('nominatim.openstreetmap.org', '/search', queryParameters);

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

