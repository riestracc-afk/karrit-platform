class VehicleCategory {
  VehicleCategory({
    required this.id,
    required this.label,
    required this.capacity,
  });

  final String id;
  final String label;
  final String capacity;

  factory VehicleCategory.fromJson(Map<String, dynamic> json) {
    return VehicleCategory(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      capacity: json['capacity'] as String? ?? '',
    );
  }
}

class ServiceItem {
  ServiceItem({required this.label});

  final String label;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(label: json['label'] as String? ?? 'Servicio');
  }
}

class PricingRow {
  PricingRow({
    required this.categoryLabel,
    required this.startFare,
    required this.perKmRate,
    required this.waitPerMinRate,
  });

  final String categoryLabel;
  final double startFare;
  final double perKmRate;
  final double waitPerMinRate;

  factory PricingRow.fromJson(Map<String, dynamic> json) {
    return PricingRow(
      categoryLabel: json['categoryLabel'] as String? ?? '',
      startFare: (json['startFare'] as num?)?.toDouble() ?? 0,
      perKmRate: (json['perKmRate'] as num?)?.toDouble() ?? 0,
      waitPerMinRate: (json['waitPerMinRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class QuoteResult {
  QuoteResult({required this.fareEstimate});

  final double fareEstimate;

  String get currencyFormatted => 'MXN ${fareEstimate.toStringAsFixed(2)}';

  factory QuoteResult.fromJson(Map<String, dynamic> json) {
    return QuoteResult(
      fareEstimate: (json['fareEstimate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TimelineEvent {
  TimelineEvent({required this.label, required this.at});

  final String label;
  final String at;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      label: json['label'] as String? ?? '',
      at: json['at'] as String? ?? '',
    );
  }
}

class RideDriver {
  RideDriver({required this.id, required this.name});

  final String id;
  final String name;

  factory RideDriver.fromJson(Map<String, dynamic> json) {
    return RideDriver(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Conductor',
    );
  }
}

class RideData {
  RideData({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.category,
    required this.service,
    required this.status,
    required this.routeType,
    required this.fareEstimate,
    required this.tripDistanceKm,
    required this.progress,
    required this.timeline,
    required this.etaMin,
    required this.driver,
    required this.requestedAt,
  });

  final String id;
  final String pickup;
  final String dropoff;
  final String category;
  final String service;
  final String status;
  final String routeType;
  final double fareEstimate;
  final double tripDistanceKm;
  final double progress;
  final List<TimelineEvent> timeline;
  final int? etaMin;
  final RideDriver? driver;
  final String requestedAt;

  factory RideData.fromJson(Map<String, dynamic> json) {
    final timelineRaw = json['timeline'] as List<dynamic>? ?? [];

    return RideData(
      id: json['id'] as String? ?? '',
      pickup: json['pickup'] as String? ?? '',
      dropoff: json['dropoff'] as String? ?? '',
      category: json['category'] as String? ?? '',
      service: json['service'] as String? ?? '',
      status: json['status'] as String? ?? '',
      routeType: json['routeType'] as String? ?? 'local',
      fareEstimate: (json['fareEstimate'] as num?)?.toDouble() ?? 0,
      tripDistanceKm: (json['tripDistanceKm'] as num?)?.toDouble() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      timeline: timelineRaw
          .whereType<Map<String, dynamic>>()
          .map(TimelineEvent.fromJson)
          .toList(),
      etaMin: (json['etaMin'] as num?)?.toInt(),
        requestedAt: json['requestedAt'] as String? ?? '',
      driver: json['driver'] is Map<String, dynamic>
          ? RideDriver.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DriverPosition {
  DriverPosition({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.available,
    required this.vehicleName,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final bool available;
  final String vehicleName;

  factory DriverPosition.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] as Map<String, dynamic>? ?? const {};
    return DriverPosition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Conductor',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      available: json['available'] as bool? ?? false,
      vehicleName: vehicle['name'] as String? ?? 'Vehiculo',
    );
  }
}

class DriverDetail {
  DriverDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.capacity,
    required this.available,
    required this.rating,
    required this.completedRides,
    required this.vehicleName,
  });

  final String id;
  final String name;
  final String category;
  final String capacity;
  final bool available;
  final String rating;
  final int completedRides;
  final String vehicleName;

  factory DriverDetail.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] as Map<String, dynamic>? ?? const {};
    return DriverDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Conductor',
      category: json['category'] as String? ?? '',
      capacity: json['capacity'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      rating: json['rating'] as String? ?? '0.00',
      completedRides: (json['completedRides'] as num?)?.toInt() ?? 0,
      vehicleName: vehicle['name'] as String? ?? 'Vehiculo',
    );
  }
}

class AdminCategoryConfig {
  AdminCategoryConfig({
    required this.startFare,
    required this.extraKmRate,
    required this.operationalPerMinRate,
  });

  final double startFare;
  final double extraKmRate;
  final double operationalPerMinRate;

  factory AdminCategoryConfig.fromJson(Map<String, dynamic> json) {
    return AdminCategoryConfig(
      startFare: (json['startFare'] as num?)?.toDouble() ?? 0,
      extraKmRate: (json['extraKmRate'] as num?)?.toDouble() ?? 0,
      operationalPerMinRate: (json['operationalPerMinRate'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startFare': startFare,
      'extraKmRate': extraKmRate,
      'operationalPerMinRate': operationalPerMinRate,
    };
  }
}

class AdminPricingConfig {
  AdminPricingConfig({
    required this.foraneoThresholdKm,
    required this.includedKmInStartFare,
    required this.foraneoMultiplier,
    required this.defaultLoadingMinutes,
    required this.defaultTransferMinutes,
    required this.defaultUnloadingMinutes,
    required this.loadPersonnelUnitCost,
    required this.unloadPersonnelUnitCost,
    required this.categories,
    required this.municipalities,
  });

  final double foraneoThresholdKm;
  final double includedKmInStartFare;
  final double foraneoMultiplier;
  final double defaultLoadingMinutes;
  final double defaultTransferMinutes;
  final double defaultUnloadingMinutes;
  final double loadPersonnelUnitCost;
  final double unloadPersonnelUnitCost;
  final Map<String, AdminCategoryConfig> categories;
  final List<String> municipalities;

  factory AdminPricingConfig.fromJson(Map<String, dynamic> json) {
    final categoriesRaw = json['categories'] as Map<String, dynamic>? ?? const {};
    final municipalitiesRaw = json['municipalities'] as List<dynamic>? ?? const [];

    return AdminPricingConfig(
      foraneoThresholdKm: (json['foraneoThresholdKm'] as num?)?.toDouble() ?? 0,
      includedKmInStartFare: (json['includedKmInStartFare'] as num?)?.toDouble() ?? 0,
      foraneoMultiplier: (json['foraneoMultiplier'] as num?)?.toDouble() ?? 1,
      defaultLoadingMinutes: (json['defaultLoadingMinutes'] as num?)?.toDouble() ?? 0,
      defaultTransferMinutes: (json['defaultTransferMinutes'] as num?)?.toDouble() ?? 0,
      defaultUnloadingMinutes: (json['defaultUnloadingMinutes'] as num?)?.toDouble() ?? 0,
      loadPersonnelUnitCost: (json['loadPersonnelUnitCost'] as num?)?.toDouble() ?? 0,
      unloadPersonnelUnitCost: (json['unloadPersonnelUnitCost'] as num?)?.toDouble() ?? 0,
      categories: categoriesRaw.map(
        (key, value) => MapEntry(
          key,
          AdminCategoryConfig.fromJson(value as Map<String, dynamic>),
        ),
      ),
      municipalities: municipalitiesRaw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foraneoThresholdKm': foraneoThresholdKm,
      'includedKmInStartFare': includedKmInStartFare,
      'foraneoMultiplier': foraneoMultiplier,
      'defaultLoadingMinutes': defaultLoadingMinutes,
      'defaultTransferMinutes': defaultTransferMinutes,
      'defaultUnloadingMinutes': defaultUnloadingMinutes,
      'loadPersonnelUnitCost': loadPersonnelUnitCost,
      'unloadPersonnelUnitCost': unloadPersonnelUnitCost,
      'categories': categories.map((key, value) => MapEntry(key, value.toJson())),
      'municipalities': municipalities,
    };
  }
}
