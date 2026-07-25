import 'dart:typed_data';

/// Represents a discovered BLE device in scanning mode.
class BleDevice {
  final String id;
  final String name;
  final int rssi;
  final int hops; // Always 1 for directly discovered BLE neighbors
  final DateTime lastSeen;

  BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.hops = 1,
    required this.lastSeen,
  });

  BleDevice copyWith({
    String? name,
    int? rssi,
    int? hops,
    DateTime? lastSeen,
  }) {
    return BleDevice(
      id: id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      hops: hops ?? this.hops,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// Connection status between the local device and a peer.
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

/// Represents a connection event.
class BleConnectionEvent {
  final String deviceId;
  final ConnectionStatus status;

  BleConnectionEvent(this.deviceId, this.status);
}

/// Represents a packet of raw bytes received from a direct neighbor.
class BleDataPacket {
  final String deviceId; // The ID of the direct neighbor who sent this data
  final Uint8List data;

  BleDataPacket(this.deviceId, this.data);
}

/// Abstract contract for BLE Central and Peripheral operations.
abstract class BleService {
  /// Stream of discovered devices.
  Stream<List<BleDevice>> get discoveredDevices;

  /// Stream of connection state updates.
  Stream<BleConnectionEvent> get connectionStateChanges;

  /// Stream of raw incoming byte packets.
  Stream<BleDataPacket> get incomingData;

  /// Starts scanning for nearby mesh nodes.
  Future<void> startScanning();

  /// Stops scanning for nearby mesh nodes.
  Future<void> stopScanning();

  /// Starts advertising this node over BLE.
  Future<void> startAdvertising(String nickname, String userId);

  /// Stops advertising this node.
  Future<void> stopAdvertising();

  /// Connects to a nearby discovered node.
  Future<void> connectTo(String deviceId);

  /// Disconnects from a node.
  Future<void> disconnectFrom(String deviceId);

  /// Sends raw data bytes to a directly connected neighbor.
  Future<void> sendData(String deviceId, Uint8List data);

  /// Cleans up resources.
  Future<void> dispose();
}
