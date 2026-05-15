import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: query,
    );
  }

  Future<Map<String, VehicleCategory>> getCategories() async {
    final response = await http.get(_uri('/api/categories'));
    _throwOnError(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data.map((k, v) =>
        MapEntry(k, VehicleCategory.fromJson(v as Map<String, dynamic>)));
  }

  Future<Map<String, ServiceItem>> getServices(String category) async {
    final response = await http.get(_uri('/api/services/$category'));
    _throwOnError(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data.map(
        (k, v) => MapEntry(k, ServiceItem.fromJson(v as Map<String, dynamic>)));
  }

  Future<List<PricingRow>> getPricing() async {
    final response = await http.get(_uri('/api/pricing'));
    _throwOnError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => PricingRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<QuoteResult> getQuote({
    required String category,
    required String service,
    required String pickup,
    required String dropoff,
    required double distance,
  }) async {
    final response = await http.get(
      _uri('/api/quote', {
        'category': category,
        'service': service,
        'pickup': pickup,
        'dropoff': dropoff,
        'distance': distance.toString(),
      }),
    );
    _throwOnError(response);
    return QuoteResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RideData> createRide({
    required String pickup,
    required String dropoff,
    required String category,
    required String service,
    required double distance,
    double? pickupLat,
    double? pickupLng,
    String? scheduledAt,
  }) async {
    final payload = {
      'pickup': pickup,
      'dropoff': dropoff,
      'category': category,
      'service': service,
      'distance': distance,
      if (scheduledAt != null && scheduledAt.trim().isNotEmpty)
        'scheduledAt': scheduledAt,
      'pickupPoint': {
        'lat': pickupLat ?? 40.4168,
        'lng': pickupLng ?? -3.7038,
      }
    };

    final response = await http.post(
      _uri('/api/rides'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _throwOnError(response);
    return RideData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RideData> getRide(String id) async {
    final response = await http.get(_uri('/api/rides/$id'));
    _throwOnError(response);
    return RideData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RideData> cancelRide(String id) async {
    final response = await http.post(_uri('/api/rides/$id/cancel'));
    _throwOnError(response);
    return RideData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AdminPricingConfig> getAdminPricingConfig() async {
    final response = await http.get(_uri('/api/admin/pricing-config'));
    _throwOnError(response);
    return AdminPricingConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AdminPricingConfig> saveAdminPricingConfig(
      AdminPricingConfig config) async {
    final response = await http.put(
      _uri('/api/admin/pricing-config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(config.toJson()),
    );
    _throwOnError(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminPricingConfig.fromJson(data['config'] as Map<String, dynamic>);
  }

  Future<List<DriverDetail>> getDrivers() async {
    final response = await http.get(_uri('/api/drivers'));
    _throwOnError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => DriverDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RideData>> getDriverRides({
    String? driverId,
    bool activeOnly = false,
    int? scheduledWindowHours,
  }) async {
    final query = <String, String>{
      if (driverId != null && driverId.isNotEmpty) 'driverId': driverId,
      if (activeOnly) 'active': '1',
      if (scheduledWindowHours != null && scheduledWindowHours > 0)
        'scheduledWindowHours': '$scheduledWindowHours',
    };
    final response = await http.get(_uri('/api/driver/rides', query));
    _throwOnError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => RideData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DriverDetail> updateDriverAvailability(
      String driverId, bool available) async {
    final response = await http.patch(
      _uri('/api/drivers/$driverId/availability'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'available': available}),
    );
    _throwOnError(response);
    return DriverDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RideData> updateRideStatus(String rideId, String status,
      {String? driverId}) async {
    final response = await http.post(
      _uri('/api/driver/rides/$rideId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        if (driverId != null && driverId.trim().isNotEmpty)
          'driverId': driverId,
      }),
    );
    _throwOnError(response);
    return RideData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'HTTP ${response.statusCode}';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final err = body['error'];
      if (err is String && err.isNotEmpty) {
        message = err;
      }
    } catch (_) {
      // Ignora parseo de error.
    }

    throw Exception(message);
  }
}
