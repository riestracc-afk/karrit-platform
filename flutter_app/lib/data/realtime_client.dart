import 'package:socket_io_client/socket_io_client.dart' as io;

import '../domain/models.dart';

class RealtimeClient {
  RealtimeClient(this.baseUrl);

  final String baseUrl;
  io.Socket? _socket;

  void connect({
    required void Function(List<DriverPosition> drivers) onDriversUpdate,
    required void Function(RideData ride) onRideUpdate,
    void Function()? onConnected,
    void Function(dynamic error)? onError,
  }) {
    disconnect();

    _socket = io.io(
      baseUrl,
      <String, dynamic>{
        'path': '/socket.io',
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'reconnection': true,
        'timeout': 20000,
      },
    );

    _socket!.onConnect((_) {
      if (onConnected != null) {
        onConnected();
      }
    });

    _socket!.on('drivers:update', (payload) {
      if (payload is! List) {
        return;
      }

      final drivers = payload
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .map(DriverPosition.fromJson)
          .toList();

      onDriversUpdate(drivers);
    });

    _socket!.on('ride:update', (payload) {
      if (payload is! Map) {
        return;
      }

      final ride = RideData.fromJson(payload.cast<String, dynamic>());
      onRideUpdate(ride);
    });

    _socket!.onError(onError ?? (_) {});
    _socket!.onConnectError(onError ?? (_) {});
  }

  void watchRide(String rideId) {
    if (rideId.isEmpty) {
      return;
    }
    _socket?.emit('ride:watch', rideId);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
