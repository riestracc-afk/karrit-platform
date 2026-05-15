import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_base.dart';
import 'data/address_store.dart';
import 'data/api_client.dart';
import 'data/geocoding_client.dart';
import 'data/realtime_client.dart';
import 'domain/models.dart';
import 'state/ride_controller.dart';

void main() {
  runApp(const KarrytFlutterApp());
}

const List<String> _monthShortLabels = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String formatLocalDateTime(DateTime value) {
  final local = value.toLocal();
  final month = _monthShortLabels[local.month - 1];
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $month ${local.year}, $hour:$minute';
}

String formatScheduledAtLocal(String? isoValue) {
  if (isoValue == null || isoValue.trim().isEmpty) {
    return 'No programado';
  }

  final parsed = DateTime.tryParse(isoValue);
  if (parsed == null) {
    return isoValue;
  }

  return formatLocalDateTime(parsed);
}

class KarrytFlutterApp extends StatelessWidget {
  const KarrytFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F4CFF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karryt Usuario',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      ),
      home: const RideScreen(),
    );
  }
}

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key});

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int _index = 0;

  static const _tabs = [
    RideScreen(),
    AdminScreen(),
    DriverScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Usuario',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Chofer',
          ),
        ],
      ),
    );
  }
}

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

enum MapPickMode { pickup, dropoff }

class _RideScreenState extends State<RideScreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _dropoffController;
  late final TextEditingController _distanceController;
  late final ScrollController _pageScrollController;

  late final RideController _controller;
  late final GeocodingClient _geocodingClient;
  late final AddressStore _addressStore;
  late final MapController _mapController;

  final GlobalKey _requestSectionKey = GlobalKey();
  final GlobalKey _mapSectionKey = GlobalKey();
  final GlobalKey _pricingSectionKey = GlobalKey();

  static const _defaultCenter = LatLng(25.6866, -100.3161);
  MapPickMode _mapPickMode = MapPickMode.pickup;
  LatLng? _pickupPoint;
  LatLng? _dropoffPoint;
  bool _locating = false;
  bool _resolvingAddress = false;
  bool _searchingPickup = false;
  bool _searchingDropoff = false;
  DateTime? _scheduledAt;
  String? _locationStatus;
  List<GeocodeSuggestion> _recentAddresses = const [];
  List<GeocodeSuggestion> _favoriteAddresses = const [];
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();

    final baseUrl = resolveApiBaseUrl();
    _controller = RideController(
      apiClient: ApiClient(baseUrl),
      realtimeClient: RealtimeClient(baseUrl),
    )..init();
    _geocodingClient = GeocodingClient();
    _addressStore = AddressStore(baseUrl: baseUrl);
    _mapController = MapController();
    _pageScrollController = ScrollController();

    _pickupController =
        TextEditingController(text: _controller.pickupText.value)
          ..addListener(() {
            _controller.pickupText.value = _pickupController.text;
          });

    _dropoffController =
        TextEditingController(text: _controller.dropoffText.value)
          ..addListener(() {
            _controller.dropoffText.value = _dropoffController.text;
          });

    _distanceController =
        TextEditingController(text: _controller.distanceText.value)
          ..addListener(() {
            _controller.distanceText.value = _distanceController.text;
          });

    _pickupPoint = _defaultCenter;
    _controller.setPickupPoint(
        _defaultCenter.latitude, _defaultCenter.longitude);
    _pickupController.text = _formatCoordsLabel('Ubicacion', _defaultCenter);
    _loadSavedAddresses();
  }

  Future<void> _scrollToSection(GlobalKey key, int index) async {
    setState(() {
      _currentNavIndex = index;
    });

    final context = key.currentContext;
    if (context == null) {
      return;
    }

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  void _syncNavIndexFromScroll() {
    int nextIndex = _currentNavIndex;

    bool isSectionAboveThreshold(GlobalKey key) {
      final context = key.currentContext;
      if (context == null) {
        return false;
      }

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        return false;
      }

      final dy = renderObject.localToGlobal(Offset.zero).dy;
      return dy <= 180;
    }

    if (isSectionAboveThreshold(_pricingSectionKey)) {
      nextIndex = 2;
    } else if (isSectionAboveThreshold(_mapSectionKey)) {
      nextIndex = 1;
    } else {
      nextIndex = 0;
    }

    if (nextIndex != _currentNavIndex && mounted) {
      setState(() {
        _currentNavIndex = nextIndex;
      });
    }
  }

  Future<void> _loadSavedAddresses() async {
    final recents = await _addressStore.loadRecent();
    final favorites = await _addressStore.loadFavorites();
    if (!mounted) {
      return;
    }

    setState(() {
      _recentAddresses = recents;
      _favoriteAddresses = favorites;
    });
  }

  bool _isFavoriteAddress(GeocodeSuggestion value) {
    return _favoriteAddresses
        .any((item) => item.displayName == value.displayName);
  }

  Future<void> _rememberRecentAddress(GeocodeSuggestion value) async {
    final deduped = [
      value,
      ..._recentAddresses
          .where((item) => item.displayName != value.displayName),
    ].take(12).toList();

    setState(() {
      _recentAddresses = deduped;
    });

    await _addressStore.saveRecent(deduped);
  }

  Future<void> _toggleFavoriteAddress(GeocodeSuggestion value) async {
    final exists = _isFavoriteAddress(value);
    final updated = exists
        ? _favoriteAddresses
            .where((item) => item.displayName != value.displayName)
            .toList()
        : [value, ..._favoriteAddresses].take(20).toList();

    setState(() {
      _favoriteAddresses = updated;
      _locationStatus = exists
          ? 'Direccion eliminada de favoritos.'
          : 'Direccion agregada a favoritos.';
    });

    await _addressStore.saveFavorites(updated);
  }

  Future<void> _removeFavoriteAddress(GeocodeSuggestion value) async {
    final updated = _favoriteAddresses
        .where((item) => item.displayName != value.displayName)
        .toList();

    setState(() {
      _favoriteAddresses = updated;
      _locationStatus = 'Favorito eliminado.';
    });

    await _addressStore.saveFavorites(updated);
  }

  Future<void> _applySuggestion(GeocodeSuggestion selected,
      {required bool isPickup}) async {
    final point = LatLng(selected.lat, selected.lng);

    setState(() {
      if (isPickup) {
        _pickupPoint = point;
        _pickupController.text = selected.displayName;
        _controller.setPickupPoint(point.latitude, point.longitude);
        _locationStatus = 'Origen actualizado desde seleccion rapida.';
      } else {
        _dropoffPoint = point;
        _dropoffController.text = selected.displayName;
        _controller.setDropoffPoint(point.latitude, point.longitude);
        _locationStatus = 'Destino actualizado desde seleccion rapida.';
      }
    });

    _mapController.move(point, 14);
    _syncDistanceFromMap();
    await _rememberRecentAddress(selected);
  }

  Future<void> _pickFromSaved(
      {required bool favorites, required bool isPickup}) async {
    final source = favorites ? _favoriteAddresses : _recentAddresses;
    if (source.isEmpty) {
      setState(() {
        _locationStatus = favorites
            ? 'No hay direcciones favoritas guardadas.'
            : 'No hay direcciones recientes guardadas.';
      });
      return;
    }

    final selected = await showModalBottomSheet<GeocodeSuggestion>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            itemCount: source.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = source[index];
              return ListTile(
                leading: Icon(isPickup ? Icons.location_on : Icons.flag),
                title: Text(
                  item.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                    '${item.lat.toStringAsFixed(5)}, ${item.lng.toStringAsFixed(5)}'),
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    await _applySuggestion(selected, isPickup: isPickup);
  }

  String _compactAddress(String value, {int maxLength = 34}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }

    return '${normalized.substring(0, maxLength - 1).trimRight()}…';
  }

  Widget _buildSavedAddressChips({required bool isPickup}) {
    final recents = _recentAddresses.take(4).toList();
    final favorites = _favoriteAddresses.take(4).toList();

    if (recents.isEmpty && favorites.isEmpty) {
      return const SizedBox.shrink();
    }

    final label = isPickup ? 'Origen' : 'Destino';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (favorites.isNotEmpty) ...[
            const Text('Favoritos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: favorites.map((item) {
                return InputChip(
                  avatar: const Icon(Icons.star, size: 16),
                  label: Text(
                    _compactAddress(item.displayName, maxLength: 28),
                    style: const TextStyle(fontSize: 12),
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => _applySuggestion(item, isPickup: isPickup),
                  onDeleted: () => _removeFavoriteAddress(item),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (recents.isNotEmpty) ...[
            Text('Recientes $label',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recents.map((item) {
                return ActionChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text(
                    _compactAddress(item.displayName, maxLength: 28),
                    style: const TextStyle(fontSize: 12),
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => _applySuggestion(item, isPickup: isPickup),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCoordsLabel(String label, LatLng point) {
    return '$label: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  double _distanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;

    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    return earthRadiusKm * c;
  }

  void _syncDistanceFromMap() {
    if (_pickupPoint == null || _dropoffPoint == null) {
      return;
    }

    final km = _distanceKm(_pickupPoint!, _dropoffPoint!);
    final value = km.toStringAsFixed(1);
    _distanceController.text = value;
    _controller.distanceText.value = value;
    _controller.quote();
  }

  void _onMapTap(TapPosition _, LatLng point) {
    final isPickup = _mapPickMode == MapPickMode.pickup;
    setState(() {
      if (isPickup) {
        _pickupPoint = point;
        _pickupController.text = _formatCoordsLabel('Ubicacion', point);
        _controller.setPickupPoint(point.latitude, point.longitude);
      } else {
        _dropoffPoint = point;
        _dropoffController.text = _formatCoordsLabel('Destino', point);
        _controller.setDropoffPoint(point.latitude, point.longitude);
      }
    });

    _syncDistanceFromMap();
    _resolveAddress(point: point, isPickup: isPickup);
  }

  Future<void> _resolveAddress(
      {required LatLng point, required bool isPickup}) async {
    if (_resolvingAddress) {
      return;
    }

    setState(() {
      _resolvingAddress = true;
    });

    try {
      final address = await _geocodingClient.reverseGeocode(
          point.latitude, point.longitude);
      if (!mounted || address == null || address.isEmpty) {
        return;
      }

      setState(() {
        if (isPickup) {
          _pickupController.text = address;
          _locationStatus = 'Origen actualizado con direccion real.';
        } else {
          _dropoffController.text = address;
          _locationStatus = 'Destino actualizado con direccion real.';
        }
      });

      await _rememberRecentAddress(
        GeocodeSuggestion(
            displayName: address, lat: point.latitude, lng: point.longitude),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationStatus =
            'No se pudo resolver direccion, se mantienen coordenadas.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _resolvingAddress = false;
        });
      }
    }
  }

  Future<void> _searchAddress({required bool isPickup}) async {
    final query = isPickup
        ? _pickupController.text.trim()
        : _dropoffController.text.trim();
    if (query.length < 3) {
      setState(() {
        _locationStatus =
            'Escribe al menos 3 caracteres para buscar direcciones.';
      });
      return;
    }

    setState(() {
      if (isPickup) {
        _searchingPickup = true;
      } else {
        _searchingDropoff = true;
      }
      _locationStatus = null;
    });

    try {
      final results = await _geocodingClient.searchAddresses(query);
      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        setState(() {
          _locationStatus =
              'No se encontraron coincidencias para la direccion.';
        });
        return;
      }

      final selected = await showModalBottomSheet<GeocodeSuggestion>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = results[index];
                return ListTile(
                  leading: Icon(isPickup ? Icons.location_on : Icons.flag),
                  title: Text(
                    item.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                      '${item.lat.toStringAsFixed(5)}, ${item.lng.toStringAsFixed(5)}'),
                  trailing: IconButton(
                    icon: Icon(_isFavoriteAddress(item)
                        ? Icons.star
                        : Icons.star_border),
                    onPressed: () {
                      _toggleFavoriteAddress(item);
                    },
                  ),
                  onTap: () => Navigator.of(context).pop(item),
                );
              },
            ),
          );
        },
      );

      if (selected == null || !mounted) {
        return;
      }

      await _applySuggestion(selected, isPickup: isPickup);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationStatus = 'No se pudo buscar direcciones en este momento.';
      });
    } finally {
      if (mounted) {
        setState(() {
          if (isPickup) {
            _searchingPickup = false;
          } else {
            _searchingDropoff = false;
          }
        });
      }
    }
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _locating = true;
      _locationStatus = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus =
              'Activa el GPS del dispositivo para usar tu ubicacion.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Permiso de ubicacion denegado.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final point = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _pickupPoint = point;
        _pickupController.text = _formatCoordsLabel('Mi ubicacion', point);
        _controller.setPickupPoint(point.latitude, point.longitude);
        _locationStatus = 'Ubicacion detectada correctamente.';
      });

      _mapController.move(point, 14);
      _syncDistanceFromMap();
      await _resolveAddress(point: point, isPickup: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationStatus = 'No se pudo obtener tu ubicacion en este momento.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  String _formatScheduledAt(DateTime value) {
    return formatLocalDateTime(value);
  }

  Future<void> _pickScheduledAt() async {
    final now = DateTime.now();
    final initial = _scheduledAt?.isAfter(now) == true
        ? _scheduledAt!
        : now.add(const Duration(minutes: 30));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (scheduled.isBefore(now)) {
      setState(() {
        _locationStatus = 'Selecciona una hora futura para programar el viaje.';
      });
      return;
    }

    setState(() {
      _scheduledAt = scheduled;
      _locationStatus =
          'Viaje programado para ${_formatScheduledAt(scheduled)}.';
    });
  }

  Future<void> _setScheduledTimeManually() async {
    final now = DateTime.now();
    final base = _scheduledAt ?? now.add(const Duration(minutes: 30));
    final controller = TextEditingController(
      text:
          '${base.hour.toString().padLeft(2, '0')}:${base.minute.toString().padLeft(2, '0')}',
    );
    String? errorText;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Asignar hora manual'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Formato HH:mm. Se conserva la fecha elegida o la de hoy.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: 'Hora',
                      hintText: '18:30',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final match = RegExp(r'^(\d{1,2}):(\d{2})$')
                        .firstMatch(controller.text.trim());
                    if (match == null) {
                      setModalState(() {
                        errorText = 'Usa el formato HH:mm';
                      });
                      return;
                    }

                    final hour = int.parse(match.group(1)!);
                    final minute = int.parse(match.group(2)!);
                    if (hour > 23 || minute > 59) {
                      setModalState(() {
                        errorText = 'Ingresa una hora valida';
                      });
                      return;
                    }

                    final selected =
                        DateTime(base.year, base.month, base.day, hour, minute);
                    if (selected.isBefore(now)) {
                      setModalState(() {
                        errorText = 'La hora debe ser futura';
                      });
                      return;
                    }

                    Navigator.of(context).pop(selected);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _scheduledAt = result;
      _locationStatus = 'Viaje programado para ${_formatScheduledAt(result)}.';
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _distanceController.dispose();
    _pageScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F4CFF),
                    const Color(0xFF0F4CFF).withOpacity(0.85),
                  ],
                ),
              ),
            ),
            titleSpacing: 8,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/karryt.png',
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 48,
                    child: Icon(Icons.local_shipping, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Karryt',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Plataforma de Cargas',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: _controller.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _controller.init,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis == Axis.vertical &&
                          notification.depth == 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _syncNavIndexFromScroll();
                          }
                        });
                      }
                      return false;
                    },
                    child: ListView(
                      controller: _pageScrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_controller.error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(_controller.error!,
                                style: TextStyle(color: Colors.red.shade700)),
                          ),
                          const SizedBox(height: 12),
                        ],
                        KeyedSubtree(
                            key: _requestSectionKey,
                            child: _buildRequestCard()),
                        const SizedBox(height: 16),
                        _buildRideCard(),
                        const SizedBox(height: 16),
                        KeyedSubtree(
                            key: _mapSectionKey, child: _buildMapCard()),
                        const SizedBox(height: 16),
                        KeyedSubtree(
                            key: _pricingSectionKey,
                            child: _buildPricingCard()),
                        const SizedBox(height: 96),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.88),
                        const Color(0xFFF4F8FF).withValues(alpha: 0.84),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x220F1A2E),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: Colors.transparent,
                      indicatorColor:
                          const Color(0xFF0F4CFF).withValues(alpha: 0.16),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);
                        return TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w700,
                          color: selected
                              ? const Color(0xFF0F4CFF)
                              : const Color(0xFF5F6C80),
                        );
                      }),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        final selected = states.contains(WidgetState.selected);
                        return IconThemeData(
                          color: selected
                              ? const Color(0xFF0F4CFF)
                              : const Color(0xFF5F6C80),
                          size: selected ? 26 : 24,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: _currentNavIndex,
                      elevation: 0,
                      height: 72,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: (index) {
                        if (index == 0) {
                          _scrollToSection(_requestSectionKey, 0);
                        } else if (index == 1) {
                          _scrollToSection(_mapSectionKey, 1);
                        } else {
                          _scrollToSection(_pricingSectionKey, 2);
                        }
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.local_shipping_outlined),
                          selectedIcon: Icon(Icons.local_shipping),
                          label: 'Solicitar',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.map_outlined),
                          selectedIcon: Icon(Icons.map),
                          label: 'Mapa',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: 'Tarifas',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestCard() {
    final availableDrivers =
        _controller.drivers.where((d) => d.available).length;

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Solicitar viaje de carga',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033)),
              ),
              const SizedBox(height: 4),
              Text(
                'Conductores disponibles ahora: $availableDrivers',
                style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _controller.selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: _controller.categories.entries
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value.label),
                        ))
                    .toList(),
                onChanged: _controller.selectCategory,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _controller.selectedService,
                decoration: const InputDecoration(labelText: 'Servicio'),
                items: _controller.services.entries
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  _controller.selectedService = value;
                  _controller.quote();
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pickupController,
                decoration: InputDecoration(
                  labelText: 'Punto de recoleccion',
                  prefixIcon: const Icon(Icons.my_location),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar direccion',
                    onPressed: _searchingPickup
                        ? null
                        : () => _searchAddress(isPickup: true),
                    icon: _searchingPickup
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (_) => _searchAddress(isPickup: true),
              ),
              _buildSavedAddressChips(isPickup: true),
              const SizedBox(height: 10),
              TextField(
                controller: _dropoffController,
                decoration: InputDecoration(
                  labelText: 'Destino',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar direccion',
                    onPressed: _searchingDropoff
                        ? null
                        : () => _searchAddress(isPickup: false),
                    icon: _searchingDropoff
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (_) => _searchAddress(isPickup: false),
              ),
              _buildSavedAddressChips(isPickup: false),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickFromSaved(favorites: false, isPickup: true),
                    icon: const Icon(Icons.history),
                    label: const Text('Reciente origen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickFromSaved(favorites: true, isPickup: true),
                    icon: const Icon(Icons.star),
                    label: const Text('Favorito origen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickFromSaved(favorites: false, isPickup: false),
                    icon: const Icon(Icons.history),
                    label: const Text('Reciente destino'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _pickFromSaved(favorites: true, isPickup: false),
                    icon: const Icon(Icons.star),
                    label: const Text('Favorito destino'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _distanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Distancia estimada (km)',
                  prefixIcon: Icon(Icons.straighten),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _pickScheduledAt,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _scheduledAt == null
                            ? 'Elegir fecha'
                            : '${_scheduledAt!.day.toString().padLeft(2, '0')}/${_scheduledAt!.month.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _setScheduledTimeManually,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _scheduledAt == null
                            ? 'Hora manual'
                            : '${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
              if (_scheduledAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Programado: ${_formatScheduledAt(_scheduledAt!)}',
                        style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _scheduledAt = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Limpiar'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tarifa estimada: ${_controller.fareLabel}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _controller.quoting ? null : _controller.quote,
                      child: Text(_controller.quoting
                          ? 'Calculando...'
                          : 'Recalcular tarifa'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _controller.requestingRide
                          ? null
                          : () =>
                              _controller.createRide(scheduledAt: _scheduledAt),
                      child: Text(_controller.requestingRide
                          ? 'Solicitando...'
                          : 'Solicitar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard() {
    final ride = _controller.currentRide;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seguimiento de Viaje',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (ride == null)
              const Text('Aun no has solicitado una carga.')
            else ...[
              _infoLine('ID', ride.id),
              _infoLine('Estado', statusToLabel(ride.status)),
              if (ride.scheduledAt != null)
                _infoLine(
                    'Programado', formatScheduledAtLocal(ride.scheduledAt)),
              _infoLine('Ruta', ride.routeType),
              _infoLine(
                  'Tarifa', 'MXN ${ride.fareEstimate.toStringAsFixed(2)}'),
              _infoLine(
                  'Distancia', '${ride.tripDistanceKm.toStringAsFixed(1)} km'),
              _infoLine(
                  'ETA', ride.etaMin != null ? '${ride.etaMin} min' : '--'),
              if (ride.driver != null)
                _infoLine('Conductor', ride.driver!.name),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: ride.progress.clamp(0, 1)),
              const SizedBox(height: 6),
              Text('${(ride.progress * 100).round()}% completado'),
              const SizedBox(height: 12),
              const Text('Linea de tiempo',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...ride.timeline.reversed.take(6).map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${e.label}'),
                );
              }),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed:
                    _controller.canCancel ? _controller.cancelRide : null,
                child: const Text('Cancelar viaje'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    final markers = <Marker>[
      if (_pickupPoint != null)
        Marker(
          point: _pickupPoint!,
          width: 34,
          height: 34,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 34),
        ),
      if (_dropoffPoint != null)
        Marker(
          point: _dropoffPoint!,
          width: 34,
          height: 34,
          child: const Icon(Icons.flag, color: Colors.red, size: 28),
        ),
    ];

    for (final driver in _controller.drivers) {
      markers.add(
        Marker(
          point: LatLng(driver.lat, driver.lng),
          width: 28,
          height: 28,
          child: Icon(
            Icons.local_shipping,
            color: driver.available ? Colors.green : Colors.orange,
            size: 24,
          ),
        ),
      );
    }

    final availableDrivers =
        _controller.drivers.where((d) => d.available).length;
    final routePoints = <LatLng>[
      if (_pickupPoint != null) _pickupPoint!,
      if (_dropoffPoint != null) _dropoffPoint!,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mapa en Tiempo Real',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                'Conductores activos: ${_controller.drivers.length} · disponibles: $availableDrivers'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Seleccionar origen'),
                  selected: _mapPickMode == MapPickMode.pickup,
                  onSelected: (_) {
                    setState(() {
                      _mapPickMode = MapPickMode.pickup;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Seleccionar destino'),
                  selected: _mapPickMode == MapPickMode.dropoff,
                  onSelected: (_) {
                    setState(() {
                      _mapPickMode = MapPickMode.dropoff;
                    });
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useDeviceLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(_locating ? 'Localizando...' : 'Mi ubicacion'),
                ),
              ],
            ),
            if (_locationStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                _locationStatus!,
                style: TextStyle(
                  color: (_locationStatus!.contains('correctamente') ||
                          _locationStatus!.contains('actualizado'))
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_resolvingAddress) ...[
              const SizedBox(height: 8),
              const Text(
                'Resolviendo direccion...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultCenter,
                    initialZoom: 11,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'Karryt.flutter',
                    ),
                    if (routePoints.length == 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            color: Colors.blueAccent,
                            strokeWidth: 4,
                          )
                        ],
                      ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tarifas por Categoria',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Categoria')),
                  DataColumn(label: Text('Arranque')),
                  DataColumn(label: Text('Por km')),
                  DataColumn(label: Text('Espera/min')),
                ],
                rows: _controller.pricing
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.categoryLabel)),
                          DataCell(
                              Text('MXN ${row.startFare.toStringAsFixed(0)}')),
                          DataCell(
                              Text('MXN ${row.perKmRate.toStringAsFixed(0)}')),
                          DataCell(Text(
                              'MXN ${row.waitPerMinRate.toStringAsFixed(0)}')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String statusToLabel(String status) {
  switch (status) {
    case 'searching':
      return 'Buscando conductor';
    case 'accepted':
      return 'Conductor asignado';
    case 'driver_arriving':
      return 'Conductor en camino';
    case 'in_progress':
      return 'Carga en curso';
    case 'completed':
      return 'Completado';
    case 'cancelled':
      return 'Cancelado';
    case 'no_drivers':
      return 'Sin conductores';
    default:
      return status;
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final ApiClient _apiClient;

  final Map<String, TextEditingController> _fields = {
    'foraneoThresholdKm': TextEditingController(),
    'includedKmInStartFare': TextEditingController(),
    'foraneoMultiplier': TextEditingController(),
    'defaultLoadingMinutes': TextEditingController(),
    'defaultTransferMinutes': TextEditingController(),
    'defaultUnloadingMinutes': TextEditingController(),
    'loadPersonnelUnitCost': TextEditingController(),
    'unloadPersonnelUnitCost': TextEditingController(),
    'municipalities': TextEditingController(),
  };

  final Map<String, String> _categoryLabels = {
    'pickup_mini': 'Pick-up Mini',
    'specialized_1t': 'Especializada 1 tonelada',
    'truck_3t': 'Especializada 3 toneladas',
    'dump_truck': 'Camion de Volteo',
  };

  final Map<String, Map<String, TextEditingController>> _categoryFields = {};
  List<RideData> _rides = [];

  bool _loading = true;
  bool _loadingRides = false;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(resolveApiBaseUrl());
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final controls in _categoryFields.values) {
      for (final controller in controls.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final config = await _apiClient.getAdminPricingConfig();
      _fields['foraneoThresholdKm']!.text =
          config.foraneoThresholdKm.toStringAsFixed(2);
      _fields['includedKmInStartFare']!.text =
          config.includedKmInStartFare.toStringAsFixed(2);
      _fields['foraneoMultiplier']!.text =
          config.foraneoMultiplier.toStringAsFixed(2);
      _fields['defaultLoadingMinutes']!.text =
          config.defaultLoadingMinutes.toStringAsFixed(2);
      _fields['defaultTransferMinutes']!.text =
          config.defaultTransferMinutes.toStringAsFixed(2);
      _fields['defaultUnloadingMinutes']!.text =
          config.defaultUnloadingMinutes.toStringAsFixed(2);
      _fields['loadPersonnelUnitCost']!.text =
          config.loadPersonnelUnitCost.toStringAsFixed(2);
      _fields['unloadPersonnelUnitCost']!.text =
          config.unloadPersonnelUnitCost.toStringAsFixed(2);
      _fields['municipalities']!.text = config.municipalities.join(', ');

      for (final entry in config.categories.entries) {
        final map = _categoryFields.putIfAbsent(entry.key, () {
          return {
            'startFare': TextEditingController(),
            'extraKmRate': TextEditingController(),
            'operationalPerMinRate': TextEditingController(),
          };
        });

        map['startFare']!.text = entry.value.startFare.toStringAsFixed(2);
        map['extraKmRate']!.text = entry.value.extraKmRate.toStringAsFixed(2);
        map['operationalPerMinRate']!.text =
            entry.value.operationalPerMinRate.toStringAsFixed(2);
      }

      await _loadRides();
    } catch (e) {
      _error = 'No se pudo cargar configuracion: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRides() async {
    setState(() {
      _loadingRides = true;
    });

    try {
      final rides = await _apiClient.getDriverRides(activeOnly: false);
      if (!mounted) {
        return;
      }

      setState(() {
        _rides = rides;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo cargar monitoreo de viajes: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRides = false;
        });
      }
    }
  }

  double _numField(String key, {double fallback = 0}) {
    return double.tryParse(_fields[key]!.text.trim()) ?? fallback;
  }

  double _categoryNumField(String category, String field) {
    return double.tryParse(_categoryFields[category]![field]!.text.trim()) ?? 0;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    final categories = <String, AdminCategoryConfig>{};
    for (final category in _categoryFields.keys) {
      categories[category] = AdminCategoryConfig(
        startFare: _categoryNumField(category, 'startFare'),
        extraKmRate: _categoryNumField(category, 'extraKmRate'),
        operationalPerMinRate:
            _categoryNumField(category, 'operationalPerMinRate'),
      );
    }

    final municipalities = _fields['municipalities']!
        .text
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList();

    final payload = AdminPricingConfig(
      foraneoThresholdKm: _numField('foraneoThresholdKm'),
      includedKmInStartFare: _numField('includedKmInStartFare'),
      foraneoMultiplier: _numField('foraneoMultiplier', fallback: 1),
      defaultLoadingMinutes: _numField('defaultLoadingMinutes'),
      defaultTransferMinutes: _numField('defaultTransferMinutes'),
      defaultUnloadingMinutes: _numField('defaultUnloadingMinutes'),
      loadPersonnelUnitCost: _numField('loadPersonnelUnitCost'),
      unloadPersonnelUnitCost: _numField('unloadPersonnelUnitCost'),
      categories: categories,
      municipalities: municipalities,
    );

    try {
      await _apiClient.saveAdminPricingConfig(payload);
      _success = 'Configuracion guardada correctamente.';
      await _load();
    } catch (e) {
      setState(() {
        _error = 'No se pudo guardar configuracion: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  int _countRidesByStatus(Set<String> statuses) {
    return _rides.where((ride) => statuses.contains(ride.status)).length;
  }

  Widget _buildAdminMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.18),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C2D12), Color(0xFF9A3412)],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consola Admin',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('Control operativo Karryt',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                    const SizedBox(height: 8),
                  ],
                  if (_success != null) ...[
                    Text(_success!,
                        style: TextStyle(color: Colors.green.shade700)),
                    const SizedBox(height: 8),
                  ],
                  _buildMonitoringCard(),
                  const SizedBox(height: 12),
                  _buildGeneralCard(),
                  const SizedBox(height: 12),
                  ..._categoryFields.keys.map(_buildCategoryCard),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(
                        _saving ? 'Guardando...' : 'Guardar configuracion'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildGeneralCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parametros globales',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Ajusta costos, tiempos y cobertura.',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            _numberField('foraneoThresholdKm', 'Umbral foraneo (km)'),
            _numberField('includedKmInStartFare', 'Km incluidos en arranque'),
            _numberField('foraneoMultiplier', 'Multiplicador foraneo'),
            _numberField('defaultLoadingMinutes', 'Minutos carga'),
            _numberField('defaultTransferMinutes', 'Minutos traslado'),
            _numberField('defaultUnloadingMinutes', 'Minutos descarga'),
            _numberField(
                'loadPersonnelUnitCost', 'Costo unitario personal carga'),
            _numberField(
                'unloadPersonnelUnitCost', 'Costo unitario personal descarga'),
            TextField(
              controller: _fields['municipalities'],
              decoration: const InputDecoration(
                labelText: 'Municipios (separados por coma)',
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringCard() {
    final active = _countRidesByStatus({
      'searching',
      'scheduled',
      'accepted',
      'driver_arriving',
      'in_progress'
    });
    final completed = _countRidesByStatus({'completed'});
    final incidents = _countRidesByStatus({'cancelled', 'no_drivers'});

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Monitoreo de viajes',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: _loadingRides ? null : _loadRides,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar viajes',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 210,
                  child: _buildAdminMetric(
                    icon: Icons.local_shipping_outlined,
                    label: 'Activos',
                    value: '$active',
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: _buildAdminMetric(
                    icon: Icons.check_circle_outline,
                    label: 'Completados',
                    value: '$completed',
                    color: const Color(0xFF15803D),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: _buildAdminMetric(
                    icon: Icons.warning_amber_rounded,
                    label: 'Incidencias',
                    value: '$incidents',
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingRides)
              const LinearProgressIndicator()
            else if (_rides.isEmpty)
              const Text('Sin viajes registrados por ahora.')
            else
              ..._rides.take(20).map(
                    (ride) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE3E8F2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Viaje ${ride.id}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Estado: ${statusToLabel(ride.status)}'),
                            if (ride.scheduledAt != null)
                              Text(
                                  'Programado: ${formatScheduledAtLocal(ride.scheduledAt)}'),
                            Text(
                                'Chofer: ${ride.driver?.name ?? 'Sin asignar'}'),
                            Text('Origen: ${ride.pickup}'),
                            Text('Destino: ${ride.dropoff}'),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category) {
    final controls = _categoryFields[category]!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _categoryLabels[category] ?? category,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controls['startFare'],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tarifa arranque',
                  prefixIcon: Icon(Icons.local_offer_outlined)),
            ),
            TextField(
              controller: controls['extraKmRate'],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tarifa por km extra',
                  prefixIcon: Icon(Icons.straighten)),
            ),
            TextField(
              controller: controls['operationalPerMinRate'],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tarifa por minuto operacional',
                  prefixIcon: Icon(Icons.schedule)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(String key, String label) {
    return TextField(
      controller: _fields[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  late final ApiClient _apiClient;
  Timer? _autoRefresh;

  static const String _scheduledWindowPrefsKey = 'driver.scheduledWindowHours';
  static const List<int> _windowOptions = [6, 12, 24, 48];
  static const int _defaultScheduledWindowHours = int.fromEnvironment(
      'SCHEDULED_VISIBILITY_WINDOW_HOURS',
      defaultValue: 24);

  List<DriverDetail> _drivers = [];
  List<RideData> _rides = [];
  String? _selectedDriverId;
  late final TextEditingController _customWindowController;
  bool _activeOnly = true;
  bool _loading = true;
  String? _error;
  int _scheduledWindowHours = _defaultScheduledWindowHours;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(resolveApiBaseUrl());
    _customWindowController =
        TextEditingController(text: '$_scheduledWindowHours');
    _initializeDriverScreen();
    _autoRefresh = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadRides();
      }
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _customWindowController.dispose();
    super.dispose();
  }

  Future<void> _initializeDriverScreen() async {
    await _restoreScheduledWindowPreference();
    await _refreshAll();
  }

  Future<void> _restoreScheduledWindowPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_scheduledWindowPrefsKey);
      if (stored == null || stored <= 0 || stored > 168) {
        return;
      }
      _scheduledWindowHours = stored;
      _customWindowController.text = '$stored';
    } catch (_) {
      // Ignora errores de preferencias locales.
    }
  }

  Future<void> _saveScheduledWindowPreference(int hours) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_scheduledWindowPrefsKey, hours);
    } catch (_) {
      // Ignora errores de preferencias locales.
    }
  }

  void _applyCustomWindowHours() {
    final hours = int.tryParse(_customWindowController.text.trim());
    if (hours == null || hours < 1 || hours > 168) {
      setState(() {
        _error = 'Ingresa una ventana valida entre 1 y 168 horas.';
      });
      return;
    }

    setState(() {
      _scheduledWindowHours = hours;
      _error = null;
    });
    unawaited(_saveScheduledWindowPreference(hours));
    _loadRides();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _drivers = await _apiClient.getDrivers();
      _selectedDriverId ??= _drivers.isNotEmpty ? _drivers.first.id : null;
      await _loadRides();
    } catch (e) {
      _error = 'No se pudo cargar modulo chofer: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRides() async {
    try {
      final rides = await _apiClient.getDriverRides(
        driverId: _selectedDriverId,
        activeOnly: _activeOnly,
        scheduledWindowHours: _scheduledWindowHours,
      );
      if (mounted) {
        setState(() {
          _rides = rides;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar viajes: $e';
        });
      }
    }
  }

  Future<void> _toggleAvailability(bool available) async {
    final driverId = _selectedDriverId;
    if (driverId == null) {
      return;
    }

    try {
      await _apiClient.updateDriverAvailability(driverId, available);
      await _refreshAll();
    } catch (e) {
      setState(() {
        _error = 'No se pudo actualizar disponibilidad: $e';
      });
    }
  }

  Future<void> _setRideStatus(RideData ride, String status) async {
    try {
      await _apiClient.updateRideStatus(ride.id, status,
          driverId: _selectedDriverId);
      await _loadRides();
    } catch (e) {
      setState(() {
        _error = 'No se pudo actualizar estado: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDriver = _drivers
        .where((d) => d.id == _selectedDriverId)
        .cast<DriverDetail?>()
        .firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.18),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF059669)],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Karryt Chofer',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('Aceptacion y seguimiento',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                    const SizedBox(height: 8),
                  ],
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Perfil de chofer',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDriverId,
                            decoration:
                                const InputDecoration(labelText: 'Conductor'),
                            items: _drivers
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child:
                                          Text('${d.name} (${d.vehicleName})'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDriverId = value;
                              });
                              _loadRides();
                            },
                          ),
                          const SizedBox(height: 8),
                          if (selectedDriver != null) ...[
                            Text('Categoria: ${selectedDriver.category}'),
                            Text('Capacidad: ${selectedDriver.capacity}'),
                            Text('Rating: ${selectedDriver.rating}'),
                            Text(
                                'Viajes completados: ${selectedDriver.completedRides}'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _windowOptions
                                  .map(
                                    (hours) => ChoiceChip(
                                      label: Text('${hours}h'),
                                      selected: _scheduledWindowHours == hours,
                                      onSelected: (_) {
                                        setState(() {
                                          _scheduledWindowHours = hours;
                                          _customWindowController.text =
                                              '$hours';
                                        });
                                        unawaited(
                                            _saveScheduledWindowPreference(
                                                hours));
                                        _loadRides();
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customWindowController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Ventana programada (horas)',
                                      prefixIcon: Icon(Icons.schedule_send),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: _applyCustomWindowHours,
                                  child: const Text('Aplicar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () => _toggleAvailability(true),
                                  child: const Text('Disponible'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => _toggleAvailability(false),
                                  child: const Text('Fuera de servicio'),
                                ),
                                FilterChip(
                                  label: const Text('Solo activos'),
                                  selected: _activeOnly,
                                  onSelected: (value) {
                                    setState(() {
                                      _activeOnly = value;
                                    });
                                    _loadRides();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._rides.map((ride) => _buildRideCard(ride)),
                  if (_rides.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                          'No hay viajes para este chofer con el filtro actual.'),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildRideCard(RideData ride) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Viaje ${ride.id}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Estado: ${statusToLabel(ride.status)}'),
            if (ride.scheduledAt != null)
              Text('Programado: ${formatScheduledAtLocal(ride.scheduledAt)}'),
            Text('Origen: ${ride.pickup}'),
            Text('Destino: ${ride.dropoff}'),
            Text('Tarifa: MXN ${ride.fareEstimate.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: ride.progress.clamp(0, 1)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (ride.status == 'searching')
                  FilledButton.tonal(
                    onPressed: () => _setRideStatus(ride, 'accepted'),
                    child: const Text('Aceptar viaje'),
                  ),
                OutlinedButton(
                  onPressed: () => _setRideStatus(ride, 'driver_arriving'),
                  child: const Text('En camino'),
                ),
                OutlinedButton(
                  onPressed: () => _setRideStatus(ride, 'in_progress'),
                  child: const Text('Iniciar carga'),
                ),
                FilledButton(
                  onPressed: () => _setRideStatus(ride, 'completed'),
                  child: const Text('Finalizar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
