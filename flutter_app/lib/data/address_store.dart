import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'geocoding_client.dart';

class AddressStore {
  AddressStore({required this.baseUrl});

  final String baseUrl;

  static const _recentBackupKey = 'Karryt_recent_addresses_backup';
  static const _favoriteBackupKey = 'Karryt_favorite_addresses_backup';

  Uri _uri(String path) {
    final base = Uri.parse(baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    );
  }

  Future<List<GeocodeSuggestion>> loadRecent() async {
    try {
      final response = await http.get(_uri('/api/address-recents'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final recents = data['recents'];
      if (recents is! List) {
        return const [];
      }

      final parsed = recents
          .whereType<Map>()
          .map((item) => GeocodeSuggestion.fromJson(item.cast<String, dynamic>()))
          .toList();

      if (parsed.isNotEmpty) {
        await _saveLocalRecentBackup(parsed);
      }

      return parsed;
    } catch (_) {
      return _loadLocalList(_recentBackupKey);
    }
  }

  Future<List<GeocodeSuggestion>> loadFavorites() async {
    try {
      final response = await http.get(_uri('/api/address-favorites'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final favorites = data['favorites'];
      if (favorites is! List) {
        return const [];
      }

      final parsed = favorites
          .whereType<Map>()
          .map((item) => GeocodeSuggestion.fromJson(item.cast<String, dynamic>()))
          .toList();

      if (parsed.isNotEmpty) {
        await _saveLocalFavoritesBackup(parsed);
      }

      return parsed;
    } catch (_) {
      return _loadLocalList(_favoriteBackupKey);
    }
  }

  Future<void> saveRecent(List<GeocodeSuggestion> values) async {
    final payload = {
      'recents': values
          .map((e) => {
                'displayName': e.displayName,
                'lat': e.lat,
                'lng': e.lng,
              })
          .toList()
    };

    try {
      final response = await http.put(
        _uri('/api/address-recents'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      await _saveLocalRecentBackup(values);
    } catch (_) {
      await _saveLocalRecentBackup(values);
    }
  }

  Future<void> saveFavorites(List<GeocodeSuggestion> values) async {
    final payload = {
      'favorites': values
          .map((e) => {
                'displayName': e.displayName,
                'lat': e.lat,
                'lng': e.lng,
              })
          .toList()
    };

    try {
      final response = await http.put(
        _uri('/api/address-favorites'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      await _saveLocalFavoritesBackup(values);
    } catch (_) {
      await _saveLocalFavoritesBackup(values);
    }
  }

  Future<List<GeocodeSuggestion>> _loadLocalList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final data = jsonDecode(raw);
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map>()
        .map((item) => GeocodeSuggestion.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _saveLocalFavoritesBackup(List<GeocodeSuggestion> values) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(values
        .map((e) => {
              'display_name': e.displayName,
              'lat': e.lat.toString(),
              'lon': e.lng.toString(),
            })
        .toList());
    await prefs.setString(_favoriteBackupKey, encoded);
  }

  Future<void> _saveLocalRecentBackup(List<GeocodeSuggestion> values) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(values
        .map((e) => {
              'display_name': e.displayName,
              'lat': e.lat.toString(),
              'lon': e.lng.toString(),
            })
        .toList());
    await prefs.setString(_recentBackupKey, encoded);
  }
}

