import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:bitchat/core/services/ble/ble_service.dart';

/// Represents a node's physical position in the virtual coordinate space (for UI drag & drop and RSSI calculations).
class VirtualPosition {
  double x;
  double y;
  VirtualPosition(this.x, this.y);

  double distanceTo(VirtualPosition other) {
    return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2));
  }
}

/// Information about a simulated node in the virtual medium registry.
class SimulatedNodeRegistryEntry {
  final String userId;
  String nickname;
  final VirtualPosition position;
  bool isAdvertising;
  bool isScanning;
  final Set<String> connectedPeers = {};

  // Input queues to deliver events/data to this specific node
  final StreamController<List<BleDevice>> discoveredDevicesController = StreamController.broadcast();
  final StreamController<BleConnectionEvent> connectionStateController = StreamController.broadcast();
  final StreamController<BleDataPacket> incomingDataController = StreamController.broadcast();

  SimulatedNodeRegistryEntry({
    required this.userId,
    required this.nickname,
    required this.position,
    this.isAdvertising = false,
    this.isScanning = false,
  });

  void dispose() {
    discoveredDevicesController.close();
    connectionStateController.close();
    incomingDataController.close();
  }
}

/// The mock BLE environment that routes simulated packets between virtual adapters.
class MockBleMedium {
  static final MockBleMedium instance = MockBleMedium._internal();
  MockBleMedium._internal() {
    // Start a periodic timer to update scanned devices based on positions
    Timer.periodic(const Duration(seconds: 2), (_) => _updateScans());
  }

  final Map<String, SimulatedNodeRegistryEntry> nodes = {};
  static const double maxDiscoveryDistance = 120.0; // Distance beyond which nodes can't see each other

  /// Registers or updates a node in the medium.
  void registerNode(String userId, String nickname, {double? x, double? y}) {
    if (nodes.containsKey(userId)) {
      // Update nickname if already registered
      final existing = nodes[userId]!;
      existing.nickname = nickname;
      if (x != null) existing.position.x = x;
      if (y != null) existing.position.y = y;
    } else {
      // Allocate randomized starting position
      final random = Random();
      final posX = x ?? 50.0 + random.nextDouble() * 200;
      final posY = y ?? 50.0 + random.nextDouble() * 200;
      nodes[userId] = SimulatedNodeRegistryEntry(
        userId: userId,
        nickname: nickname,
        position: VirtualPosition(posX, posY),
      );
    }
  }

  void updateNodePosition(String userId, double x, double y) {
    final node = nodes[userId];
    if (node != null) {
      node.position.x = x;
      node.position.y = y;
      _updateScans();
    }
  }

  void setAdvertising(String userId, bool active) {
    final node = nodes[userId];
    if (node != null) {
      node.isAdvertising = active;
      _updateScans();
    }
  }

  void setScanning(String userId, bool active) {
    final node = nodes[userId];
    if (node != null) {
      node.isScanning = active;
      _updateScans();
    }
  }

  void connect(String fromId, String toId) {
    final fromNode = nodes[fromId];
    final toNode = nodes[toId];
    if (fromNode != null && toNode != null) {
      fromNode.connectedPeers.add(toId);
      toNode.connectedPeers.add(fromId);

      fromNode.connectionStateController.add(BleConnectionEvent(toId, ConnectionStatus.connected));
      toNode.connectionStateController.add(BleConnectionEvent(fromId, ConnectionStatus.connected));
    }
  }

  void disconnect(String fromId, String toId) {
    final fromNode = nodes[fromId];
    final toNode = nodes[toId];
    if (fromNode != null && toNode != null) {
      fromNode.connectedPeers.remove(toId);
      toNode.connectedPeers.remove(fromId);

      fromNode.connectionStateController.add(BleConnectionEvent(toId, ConnectionStatus.disconnected));
      toNode.connectionStateController.add(BleConnectionEvent(fromId, ConnectionStatus.disconnected));
    }
  }

  void transmitData(String fromId, String toId, Uint8List data) {
    final toNode = nodes[toId];
    final fromNode = nodes[fromId];
    // Deliver data only if both nodes are registered, active, and connected
    if (toNode != null && fromNode != null && fromNode.connectedPeers.contains(toId)) {
      toNode.incomingDataController.add(BleDataPacket(fromId, data));
    }
  }

  void triggerScanUpdate() {
    _updateScans();
  }

  /// Calculates scan lists for all scanning nodes based on distances to advertising nodes.
  void _updateScans() {
    for (final scanner in nodes.values) {
      if (!scanner.isScanning) continue;

      final List<BleDevice> discovered = [];
      for (final advertiser in nodes.values) {
        if (advertiser.userId == scanner.userId) continue;
        if (!advertiser.isAdvertising) continue;

        final dist = scanner.position.distanceTo(advertiser.position);
        if (dist <= maxDiscoveryDistance) {
          // Calculate RSSI: closer is stronger, limit between -40 and -100
          final rssi = (-35 - (dist * 0.55)).round().clamp(-100, -35);
          discovered.add(
            BleDevice(
              id: advertiser.userId,
              name: advertiser.nickname,
              rssi: rssi,
              lastSeen: DateTime.now(),
            ),
          );
        }
      }
      scanner.discoveredDevicesController.add(discovered);
    }
  }

  void removeNode(String userId) {
    final node = nodes.remove(userId);
    if (node != null) {
      // Disconnect all links
      final copyConnected = Set<String>.from(node.connectedPeers);
      for (final peerId in copyConnected) {
        disconnect(userId, peerId);
      }
      node.dispose();
    }
  }

  void clear() {
    final keys = List<String>.from(nodes.keys);
    for (final k in keys) {
      removeNode(k);
    }
  }
}

/// Virtual BLE Adapter that hooks a routing engine instance to the shared Mock BLE Medium.
class VirtualBleAdapter implements BleService {
  final String userId;
  late final String _initialNickname;
  final MockBleMedium _medium = MockBleMedium.instance;

  VirtualBleAdapter(this.userId, this._initialNickname) {
    _medium.registerNode(userId, _initialNickname);
  }

  SimulatedNodeRegistryEntry get _entry => _medium.nodes[userId]!;

  @override
  Stream<List<BleDevice>> get discoveredDevices => _entry.discoveredDevicesController.stream;

  @override
  Stream<BleConnectionEvent> get connectionStateChanges => _entry.connectionStateController.stream;

  @override
  Stream<BleDataPacket> get incomingData => _entry.incomingDataController.stream;

  @override
  Future<void> startScanning() async {
    _medium.setScanning(userId, true);
  }

  @override
  Future<void> stopScanning() async {
    _medium.setScanning(userId, false);
  }

  @override
  Future<void> startAdvertising(String nickname, String userId) async {
    _medium.registerNode(userId, nickname);
    _medium.setAdvertising(userId, true);
  }

  @override
  Future<void> stopAdvertising() async {
    _medium.setAdvertising(userId, false);
  }

  @override
  Future<void> connectTo(String deviceId) async {
    _entry.connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.connecting));
    // Simulate connection lag
    await Future.delayed(const Duration(milliseconds: 300));
    _medium.connect(userId, deviceId);
  }

  @override
  Future<void> disconnectFrom(String deviceId) async {
    _medium.disconnect(userId, deviceId);
  }

  @override
  Future<void> sendData(String deviceId, Uint8List data) async {
    _medium.transmitData(userId, deviceId, data);
  }

  @override
  Future<void> dispose() async {
    _medium.removeNode(userId);
  }
}

/// The main `MockBleService` used by the primary application when running in simulated mode.
class MockBleService extends VirtualBleAdapter {
  MockBleService(String userId, String nickname) : super(userId, nickname);
}
