import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/realtime_client.dart';
import '../domain/models.dart';

class RideController extends ChangeNotifier {
  RideController({
    required ApiClient apiClient,
    required RealtimeClient realtimeClient,
  })  : _apiClient = apiClient,
        _realtimeClient = realtimeClient;

  final ApiClient _apiClient;
  final RealtimeClient _realtimeClient;

  final pickupText = ValueNotifier<String>('');
  final dropoffText = ValueNotifier<String>('');
  final distanceText = ValueNotifier<String>('10');

  Map<String, VehicleCategory> categories = {};
  Map<String, ServiceItem> services = {};
  List<PricingRow> pricing = [];
  List<DriverPosition> drivers = [];

  String? selectedCategory;
  String? selectedService;

  RideData? currentRide;
  double? pickupLat;
  double? pickupLng;
  double? dropoffLat;
  double? dropoffLng;

  bool loading = true;
  bool requestingRide = false;
  bool quoting = false;
  String fareLabel = 'MXN --.--';
  String? error;

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();

    _realtimeClient.connect(
      onDriversUpdate: (data) {
        drivers = data;
        notifyListeners();
      },
      onRideUpdate: (ride) {
        if (currentRide == null || currentRide!.id == ride.id) {
          currentRide = ride;
          notifyListeners();
        }
      },
      onError: (_) {
        // En tiempo real degradado, la app sigue operando por REST.
      },
    );

    try {
      categories = await _apiClient.getCategories();
      pricing = await _apiClient.getPricing();

      if (categories.isNotEmpty) {
        selectedCategory = categories.keys.first;
        await loadServices(selectedCategory!);
      }

      await quote();
    } catch (e) {
      error = 'No se pudo inicializar la app: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadServices(String category) async {
    try {
      services = await _apiClient.getServices(category);
      selectedService = services.isNotEmpty ? services.keys.first : null;
      notifyListeners();
    } catch (e) {
      error = 'No se pudieron cargar servicios: $e';
      notifyListeners();
    }
  }

  Future<void> selectCategory(String? category) async {
    if (category == null) {
      return;
    }

    selectedCategory = category;
    services = {};
    selectedService = null;
    notifyListeners();

    await loadServices(category);
    await quote();
  }

  Future<void> quote() async {
    if (selectedCategory == null || selectedService == null) {
      return;
    }

    final distance = double.tryParse(distanceText.value.trim()) ?? 0;

    quoting = true;
    error = null;
    notifyListeners();

    try {
      final result = await _apiClient.getQuote(
        category: selectedCategory!,
        service: selectedService!,
        pickup: pickupText.value.trim(),
        dropoff: dropoffText.value.trim(),
        distance: distance,
      );
      fareLabel = result.currencyFormatted;
    } catch (e) {
      error = 'No se pudo calcular tarifa: $e';
    } finally {
      quoting = false;
      notifyListeners();
    }
  }

  void setPickupPoint(double lat, double lng) {
    pickupLat = lat;
    pickupLng = lng;
    notifyListeners();
  }

  void setDropoffPoint(double lat, double lng) {
    dropoffLat = lat;
    dropoffLng = lng;
    notifyListeners();
  }

  Future<void> createRide() async {
    if (selectedCategory == null || selectedService == null) {
      error = 'Selecciona categoria y servicio';
      notifyListeners();
      return;
    }

    final pickup = pickupText.value.trim();
    final dropoff = dropoffText.value.trim();
    final distance = double.tryParse(distanceText.value.trim()) ?? 0;

    if (pickup.isEmpty || dropoff.isEmpty) {
      error = 'Debes capturar origen y destino';
      notifyListeners();
      return;
    }

    requestingRide = true;
    error = null;
    notifyListeners();

    try {
      final ride = await _apiClient.createRide(
        pickup: pickup,
        dropoff: dropoff,
        category: selectedCategory!,
        service: selectedService!,
        distance: distance,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
      );

      currentRide = ride;
      _realtimeClient.watchRide(ride.id);
    } catch (e) {
      error = 'No se pudo crear viaje: $e';
    } finally {
      requestingRide = false;
      notifyListeners();
    }
  }

  Future<void> cancelRide() async {
    if (currentRide == null) {
      return;
    }

    try {
      final cancelled = await _apiClient.cancelRide(currentRide!.id);
      currentRide = cancelled;
      notifyListeners();
    } catch (e) {
      error = 'No se pudo cancelar viaje: $e';
      notifyListeners();
    }
  }

  bool get canCancel {
    final status = currentRide?.status;
    return status != null &&
        status != 'completed' &&
        status != 'cancelled' &&
        status != 'no_drivers';
  }

  @override
  void dispose() {
    _realtimeClient.disconnect();
    pickupText.dispose();
    dropoffText.dispose();
    distanceText.dispose();
    super.dispose();
  }
}
