import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:ble_peripheral/ble_peripheral.dart' as bp;
import 'package:permission_handler/permission_handler.dart';
import 'ble_service.dart';

/// Real hardware Bluetooth Low Energy Service.
/// It operates as both a Central (scanning and connecting to peers)
/// and a Peripheral (GATT Server advertising itself and receiving incoming connections).
class RealBleService implements BleService {
  static const String _serviceUuid = '4a2d3c90-0f2c-11ee-be56-0242ac120002';
  static const String _identityCharUuid = '4a2d3c90-0f2c-11ee-be56-0242ac120003';
  static const String _dataCharUuid = '4a2d3c90-0f2c-11ee-be56-0242ac120004';

  final _discoveredController = StreamController<List<BleDevice>>.broadcast();
  final _connectionStateController = StreamController<BleConnectionEvent>.broadcast();
  final _incomingDataController = StreamController<BleDataPacket>.broadcast();

  // Active connections
  // We keep track of device connections by their UUID
  final Map<String, fbp.BluetoothDevice> _connectedDevices = {};
  final Map<String, fbp.BluetoothCharacteristic> _dataCharacteristics = {};

  StreamSubscription? _scanResultsSub;
  bool _isScanning = false;
  bool _isAdvertising = false;
  final Map<String, BleDevice> _discoveredCache = {};
  Timer? _cacheCleanerTimer;

  RealBleService() {
    _initPeripheral();
    _startCacheCleaner();
  }

  @override
  Stream<List<BleDevice>> get discoveredDevices => _discoveredController.stream;

  @override
  Stream<BleConnectionEvent> get connectionStateChanges => _connectionStateController.stream;

  @override
  Stream<BleDataPacket> get incomingData => _incomingDataController.stream;

  Future<void> _initPeripheral() async {
    try {
      await bp.BlePeripheral.initialize();
      
      // Setup GATT database
      final service = bp.BleService(
        uuid: _serviceUuid,
        primary: true,
        characteristics: [
          bp.BleCharacteristic(
            uuid: _identityCharUuid,
            properties: [
              bp.CharacteristicProperties.read.index,
            ],
            permissions: [
              bp.AttributePermissions.readable.index,
            ],
            value: null,
          ),
          bp.BleCharacteristic(
            uuid: _dataCharUuid,
            properties: [
              bp.CharacteristicProperties.write.index,
              bp.CharacteristicProperties.writeWithoutResponse.index,
              bp.CharacteristicProperties.notify.index,
            ],
            permissions: [
              bp.AttributePermissions.writeable.index,
              bp.AttributePermissions.readable.index,
            ],
            value: null,
          )
        ],
      );

      await bp.BlePeripheral.addService(service);

      bp.BlePeripheral.setWriteRequestCallback((deviceId, characteristicId, offset, value) {
        if (characteristicId.toLowerCase() == _dataCharUuid.toLowerCase() && value != null) {
          _incomingDataController.add(
            BleDataPacket(deviceId, value),
          );
        }
        return null;
      });

      // Handle Central connections to our GATT server
      bp.BlePeripheral.setConnectionStateChangeCallback((deviceId, connected) {
        final status = connected ? ConnectionStatus.connected : ConnectionStatus.disconnected;
        _connectionStateController.add(BleConnectionEvent(deviceId, status));
      });

    } catch (e) {
      debugPrint('Failed to initialize BLE Peripheral GATT Server: $e');
    }
  }

  /// Request Bluetooth permissions (excluding location if possible).
  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false;

    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();

    return bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        bluetoothAdvertise.isGranted;
  }

  @override
  Future<void> startScanning() async {
    if (_isScanning) return;

    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      debugPrint('BLE Scan permissions denied');
      return;
    }

    try {
      _isScanning = true;
      _discoveredCache.clear();

      _scanResultsSub = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          // Check if this advertisement contains our custom Service UUID
          final isMesh = r.advertisementData.serviceUuids.any(
            (uuid) => uuid.toString().toLowerCase() == _serviceUuid.toLowerCase(),
          );

          if (isMesh) {
            final devId = r.device.remoteId.str;
            final name = r.advertisementData.localName.isNotEmpty
                ? r.advertisementData.localName
                : r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : 'Unknown Device';

            _discoveredCache[devId] = BleDevice(
              id: devId,
              name: name,
              rssi: r.rssi,
              lastSeen: DateTime.now(),
            );
          }
        }
        _discoveredController.add(_discoveredCache.values.toList());
      });

      // Scan for devices advertising our custom service UUID
      await fbp.FlutterBluePlus.startScan(
        withServices: [fbp.Guid(_serviceUuid)],
        timeout: const Duration(hours: 24), // Keep scanning in background
        androidUsesFineLocation: false, // Ensure location permission isn't requested if possible
      );
    } catch (e) {
      _isScanning = false;
      debugPrint('Failed to start BLE Scan: $e');
    }
  }

  @override
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    _isScanning = false;
    await _scanResultsSub?.cancel();
    await fbp.FlutterBluePlus.stopScan();
  }

  @override
  Future<void> startAdvertising(String nickname, String userId) async {
    if (_isAdvertising) return;

    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      debugPrint('BLE Advertising permissions denied');
      return;
    }

    try {
      _isAdvertising = true;

      // Update the identity characteristic with our user profile JSON
      final profile = {
        'userId': userId,
        'nickname': nickname,
      };
      // bp.BlePeripheral has an updateCharacteristic value method
      // We will encode it so when centrals read our IDENTITY characteristic, they get our details.
      // Wait, let's see how value can be set. Usually updateCharacteristic handles updating the GATT database value.
      final valueBytes = Uint8List.fromList(utf8.encode(jsonEncode(profile)));
      await bp.BlePeripheral.updateCharacteristic(
        characteristicId: _identityCharUuid,
        value: valueBytes,
      );

      // Start advertising the Service UUID
      await bp.BlePeripheral.startAdvertising(
        services: [_serviceUuid],
        localName: nickname.length > 15 ? nickname.substring(0, 15) : nickname,
      );
    } catch (e) {
      _isAdvertising = false;
      debugPrint('Failed to start BLE Advertising: $e');
    }
  }

  @override
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    _isAdvertising = false;
    await bp.BlePeripheral.stopAdvertising();
  }

  @override
  Future<void> connectTo(String deviceId) async {
    if (_connectedDevices.containsKey(deviceId)) return;

    _connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.connecting));

    try {
      final fbpDevice = fbp.BluetoothDevice(remoteId: fbp.DeviceIdentifier(deviceId));
      
      // Connect to Central
      await fbpDevice.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      // Discover Services
      final services = await fbpDevice.discoverServices();
      fbp.BluetoothCharacteristic? dataChar;

      for (final s in services) {
        if (s.uuid.toString().toLowerCase() == _serviceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == _dataCharUuid.toLowerCase()) {
              dataChar = c;
            }
          }
        }
      }

      if (dataChar == null) {
        await fbpDevice.disconnect();
        throw Exception('Data characteristic not found on target device');
      }

      // Keep references
      _connectedDevices[deviceId] = fbpDevice;
      _dataCharacteristics[deviceId] = dataChar;

      // Subscribe to notifications from peer data characteristic
      await dataChar.setNotifyValue(true);
      dataChar.onValueReceived.listen((value) {
        _incomingDataController.add(BleDataPacket(deviceId, Uint8List.fromList(value)));
      });

      // Setup connection listener for disconnects
      fbpDevice.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          _handleDisconnect(deviceId);
        }
      });

      _connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.connected));
    } catch (e) {
      debugPrint('Failed to connect to device $deviceId: $e');
      _connectedDevices.remove(deviceId);
      _dataCharacteristics.remove(deviceId);
      _connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.disconnected));
    }
  }

  void _handleDisconnect(String deviceId) {
    if (_connectedDevices.containsKey(deviceId)) {
      _connectedDevices.remove(deviceId);
      _dataCharacteristics.remove(deviceId);
      _connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.disconnected));
    }
  }

  @override
  Future<void> disconnectFrom(String deviceId) async {
    final dev = _connectedDevices[deviceId];
    if (dev != null) {
      await dev.disconnect();
    }
    _handleDisconnect(deviceId);
  }

  @override
  Future<void> sendData(String deviceId, Uint8List data) async {
    // We can send data in two ways:
    // 1. If we initiated the connection (Central role), we write to the characteristic of the peripheral.
    // 2. If the peer initiated the connection (Peripheral role), we notify the central.

    // Try Central write first
    final dataChar = _dataCharacteristics[deviceId];
    if (dataChar != null) {
      try {
        await dataChar.write(data, withoutResponse: true);
        return;
      } catch (e) {
        debugPrint('Write failed as Central, trying notification: $e');
      }
    }

    // Try Peripheral notification fallback
    try {
      await bp.BlePeripheral.updateCharacteristic(
        characteristicId: _dataCharUuid,
        value: data,
        deviceId: deviceId, // Notify this specific central
      );
    } catch (e) {
      debugPrint('Failed to send data to $deviceId: $e');
    }
  }

  void _startCacheCleaner() {
    _cacheCleanerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final expiredKeys = <String>[];
      
      _discoveredCache.forEach((key, device) {
        // Discard devices not seen for more than 10 seconds
        if (now.difference(device.lastSeen).inSeconds > 10) {
          expiredKeys.add(key);
        }
      });

      if (expiredKeys.isNotEmpty) {
        for (final k in expiredKeys) {
          _discoveredCache.remove(k);
        }
        _discoveredController.add(_discoveredCache.values.toList());
      }
    });
  }

  @override
  Future<void> dispose() async {
    _cacheCleanerTimer?.cancel();
    await stopScanning();
    await stopAdvertising();
    for (final dev in _connectedDevices.values) {
      await dev.disconnect();
    }
    _connectedDevices.clear();
    _dataCharacteristics.clear();
    await _discoveredController.close();
    await _connectionStateController.close();
    await _incomingDataController.close();
  }
}
