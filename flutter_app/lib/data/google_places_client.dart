import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'geocoding_client.dart';

class GooglePlacesClient {
  GooglePlacesClient({required this.apiKey});

  final String apiKey;
  String _sessionToken = const Uuid().v4();

  static const _baseUrl = 'https://maps.googleapis.com/maps/api';

  void _refreshSessionToken() {
    _sessionToken = const Uuid().v4();
  }

  Future<List<GeocodeSuggestion>> fetchAutocompleteSuggestions(
    String query, {
    double? biasLat,
    double? biasLng,
  }) async {
    if (apiKey.isEmpty) {
      return const [];
    }

    try {
      final queryParameters = <String, String>{
        'input': query,
        'key': apiKey,
        'language': 'es',
        'sessiontoken': _sessionToken,
        'components': 'country:mx',
        'types': 'address',
      };

      if (biasLat != null && biasLng != null) {
        queryParameters['location'] = '$biasLat,$biasLng';
        queryParameters['radius'] = '40000';
      }

      final uri = Uri.parse('$_baseUrl/place/autocomplete/json').replace(
        queryParameters: queryParameters,
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        return const [];
      }

      final predictions = data['predictions'];
      if (predictions is! List) {
        return const [];
      }

      return predictions
          .whereType<Map>()
          .take(8)
          .map((item) {
            final raw = item.cast<String, dynamic>();
            final placeId = raw['place_id'] as String?;
            final structuredFormatting = raw['structured_formatting'];
            final formatting = structuredFormatting is Map
                ? structuredFormatting.cast<String, dynamic>()
                : const <String, dynamic>{};
            final mainText = (formatting['main_text'] as String?)?.trim();
            final secondaryText =
                (formatting['secondary_text'] as String?)?.trim();
            final description = (raw['description'] as String?)?.trim();

            if (placeId == null || placeId.isEmpty) {
              return null;
            }

            final fullName = secondaryText != null && secondaryText.isNotEmpty
                ? '${mainText ?? description ?? ''}, $secondaryText'
                : (mainText ?? description ?? 'Direccion');

            return GeocodeSuggestion(
              displayName: fullName,
              lat: 0,
              lng: 0,
              placeId: placeId,
              primaryText: mainText,
              secondaryText: secondaryText,
              provider: 'google',
            );
          })
          .whereType<GeocodeSuggestion>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<GeocodeSuggestion>> searchAddresses(
    String query, {
    double? biasLat,
    double? biasLng,
  }) async {
    final predictions = await fetchAutocompleteSuggestions(
      query,
      biasLat: biasLat,
      biasLng: biasLng,
    );

    final results = await Future.wait(
      predictions.map(resolveAutocompleteSuggestion),
    );
    return results.whereType<GeocodeSuggestion>().toList(growable: false);
  }

  Future<GeocodeSuggestion?> resolveAutocompleteSuggestion(
    GeocodeSuggestion suggestion,
  ) async {
    if (!suggestion.isGooglePrediction) {
      return suggestion;
    }

    final placeId = suggestion.placeId;
    if (placeId == null || placeId.isEmpty) {
      return null;
    }

    final details = await _getPlaceDetails(placeId);
    if (details == null) {
      return null;
    }

    _refreshSessionToken();
    return GeocodeSuggestion(
      displayName: suggestion.displayName,
      lat: details['lat'] as double,
      lng: details['lng'] as double,
      placeId: placeId,
      primaryText: suggestion.primaryText,
      secondaryText: suggestion.secondaryText,
      provider: 'google',
    );
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    if (apiKey.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse('$_baseUrl/geocode/json').replace(
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': apiKey,
          'language': 'es',
        },
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        return null;
      }

      final results = data['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }

      final formattedAddress = results.first['formatted_address'];
      if (formattedAddress is String && formattedAddress.isNotEmpty) {
        return formattedAddress;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>?> _getPlaceDetails(String placeId) async {
    try {
      final uri = Uri.parse('$_baseUrl/place/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'key': apiKey,
          'fields': 'geometry',
          'sessiontoken': _sessionToken,
        },
      );

      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        return null;
      }

      final result = data['result'];
      if (result is! Map) {
        return null;
      }

      final geometry = result['geometry'];
      if (geometry is! Map) {
        return null;
      }

      final location = geometry['location'];
      if (location is! Map) {
        return null;
      }

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        return null;
      }

      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }
}
