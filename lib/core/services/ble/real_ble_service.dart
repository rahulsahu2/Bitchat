import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final Map<String, StreamSubscription> _dataSubscriptions = {};
  final Map<String, StreamSubscription> _connectionSubscriptions = {};

  StreamSubscription? _scanResultsSub;
  bool _isScanning = false;
  bool _isAdvertising = false;
  final Map<String, BleDevice> _discoveredCache = {};
  Timer? _cacheCleanerTimer;

  bool _shouldScan = false;
  bool _shouldAdvertise = false;
  String? _lastAdvertisedNickname;
  String? _lastAdvertisedUserId;
  StreamSubscription? _adapterStateSub;
  StreamSubscription? _isScanningSub;

  RealBleService() {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile) {
      _initPeripheral();
      _startCacheCleaner();

      // 1. Listen to adapter state changes to auto-start/stop scanning & advertising
      _adapterStateSub = fbp.FlutterBluePlus.adapterState.listen((state) async {
        debugPrint('DEBUG: BluetoothAdapterState changed to: $state');
        if (state == fbp.BluetoothAdapterState.on) {
          if (_shouldScan && !_isScanning) {
            await startScanning();
          }
          if (_shouldAdvertise && _lastAdvertisedNickname != null && _lastAdvertisedUserId != null) {
            await startAdvertising(_lastAdvertisedNickname!, _lastAdvertisedUserId!);
          }
        } else {
          // Bluetooth turned off, reset flags and disconnect
          _isScanning = false;
          _isAdvertising = false;
          _discoveredCache.clear();
          _discoveredController.add([]);
          // Mark all devices disconnected
          for (final deviceId in _connectedDevices.keys.toList()) {
            _handleDisconnect(deviceId);
          }
        }
      });

      // 2. Listen to isScanning to auto-restart if scanning drops but _shouldScan is true
      _isScanningSub = fbp.FlutterBluePlus.isScanning.listen((scanning) {
        _isScanning = scanning;
        if (!scanning && _shouldScan) {
          // Delayed restart to avoid system throttling
          Timer(const Duration(seconds: 2), () async {
            if (_shouldScan && !_isScanning) {
              await startScanning();
            }
          });
        }
      });
    } else {
      debugPrint('RealBleService: Not on Android/iOS. Skipping BLE initialization.');
    }
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

  /// Request Bluetooth & Location permissions.
  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false;

    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
    final location = await Permission.location.request();

    return bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        bluetoothAdvertise.isGranted &&
        location.isGranted;
  }

  /// Request permissions and auto-enable Bluetooth radio if off.
  Future<bool> _ensureBluetoothOn() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return false;

    // Eagerly request Notification Permission on Android 13+
    await Permission.notification.request();

    try {
      if (await fbp.FlutterBluePlus.adapterState.first != fbp.BluetoothAdapterState.on) {
        await fbp.FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(milliseconds: 500)); // allow startup delay
      }
    } catch (e) {
      debugPrint('Failed to turn on Bluetooth: $e');
    }
    return true;
  }

  @override
  Future<void> startScanning() async {
    _shouldScan = true;
    if (_isScanning) return;

    final enabled = await _ensureBluetoothOn();
    if (!enabled) {
      debugPrint('BLE Scan initialization failed (permission or hardware off)');
      return;
    }

    try {
      _isScanning = true;
      _discoveredCache.clear();

      await _scanResultsSub?.cancel();
      _scanResultsSub = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          // Check if this advertisement contains our custom Service UUID
          final isMesh = r.advertisementData.serviceUuids.any(
            (uuid) => uuid.toString().toLowerCase() == _serviceUuid.toLowerCase(),
          );

          if (isMesh) {
            final devId = r.device.remoteId.str;
            final name = r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
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

      // Scan for 15 seconds to keep updates fresh and avoid throttling issues
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      _isScanning = false;
      debugPrint('Failed to start BLE Scan: $e');
    }
  }

  @override
  Future<void> stopScanning() async {
    _shouldScan = false;
    _isScanning = false;
    await _scanResultsSub?.cancel();
    _scanResultsSub = null;
    await fbp.FlutterBluePlus.stopScan();
  }

  @override
  Future<void> startAdvertising(String nickname, String userId) async {
    _shouldAdvertise = true;
    _lastAdvertisedNickname = nickname;
    _lastAdvertisedUserId = userId;
    if (_isAdvertising) return;

    final enabled = await _ensureBluetoothOn();
    if (!enabled) {
      debugPrint('BLE Advertising initialization failed (permission or hardware off)');
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
    _shouldAdvertise = false;
    _isAdvertising = false;
    await bp.BlePeripheral.stopAdvertising();
  }

  @override
  Future<void> connectTo(String deviceId) async {
    if (_connectedDevices.containsKey(deviceId)) return;

    // 1. Stop scanning before connecting to peripheral (crucial on Android)
    if (_isScanning) {
      await stopScanning();
    }

    _connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.connecting));

    try {
      final fbpDevice = fbp.BluetoothDevice(remoteId: fbp.DeviceIdentifier(deviceId));
      
      // Connect to Peripheral
      await fbpDevice.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      // Request larger MTU for packet transfers (default is only 23 bytes, which would truncate mesh packets)
      try {
        await fbpDevice.requestMtu(512, timeout: 5);
        debugPrint('DEBUG: MTU requested successfully');
      } catch (e) {
        debugPrint('Failed to request MTU (expected on iOS): $e');
      }

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
      final dataSub = dataChar.onValueReceived.listen((value) {
        _incomingDataController.add(BleDataPacket(deviceId, Uint8List.fromList(value)));
      });
      _dataSubscriptions[deviceId] = dataSub;

      // Setup connection listener for disconnects
      final connSub = fbpDevice.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          _handleDisconnect(deviceId);
        }
      });
      _connectionSubscriptions[deviceId] = connSub;

      _connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.connected));
    } catch (e) {
      debugPrint('Failed to connect to device $deviceId: $e');
      _handleDisconnect(deviceId);
    }
  }

  void _handleDisconnect(String deviceId) {
    _connectedDevices.remove(deviceId);
    _dataCharacteristics.remove(deviceId);
    
    _dataSubscriptions[deviceId]?.cancel();
    _dataSubscriptions.remove(deviceId);
    
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);

    _connectionStateController.add(BleConnectionEvent(deviceId, ConnectionStatus.disconnected));
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
        await dataChar.write(data, withoutResponse: false);
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
    _adapterStateSub?.cancel();
    _isScanningSub?.cancel();
    await stopScanning();
    await stopAdvertising();
    for (final dev in _connectedDevices.values) {
      await dev.disconnect();
    }
    for (final sub in _dataSubscriptions.values) {
      await sub.cancel();
    }
    for (final sub in _connectionSubscriptions.values) {
      await sub.cancel();
    }
    _connectedDevices.clear();
    _dataCharacteristics.clear();
    _dataSubscriptions.clear();
    _connectionSubscriptions.clear();
    await _discoveredController.close();
    await _connectionStateController.close();
    await _incomingDataController.close();
  }
}
