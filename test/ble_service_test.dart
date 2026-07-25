import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/core/services/ble/ble_service.dart';
import 'package:bitchat/core/services/ble/mock_ble_service.dart';

void main() {
  setUp(() {
    MockBleMedium.instance.clear();
  });

  group('Mock BLE Simulation Tests', () {
    test('Device Discovery based on distance', () async {
      final alice = VirtualBleAdapter('alice-id', 'Alice');
      final bob = VirtualBleAdapter('bob-id', 'Bob');

      // Set positions: distance = 40 (within max range 120)
      MockBleMedium.instance.updateNodePosition('alice-id', 10, 10);
      MockBleMedium.instance.updateNodePosition('bob-id', 50, 10);

      await alice.startScanning();
      await bob.startAdvertising('Bob', 'bob-id');

      // Wait a moment for the periodic scan timer
      final completer = Completer<List<BleDevice>>();
      final sub = alice.discoveredDevices.listen((devices) {
        if (devices.isNotEmpty && !completer.isCompleted) {
          completer.complete(devices);
        }
      });

      final discovered = await completer.future.timeout(const Duration(seconds: 5));
      expect(discovered.length, equals(1));
      expect(discovered.first.id, equals('bob-id'));
      expect(discovered.first.name, equals('Bob'));
      expect(discovered.first.rssi, lessThan(-50)); // RSSI calculated from distance
      expect(discovered.first.rssi, greaterThan(-90));

      await sub.cancel();
      await alice.stopScanning();
      await bob.stopAdvertising();
      await alice.dispose();
      await bob.dispose();
    });

    test('Out of Range Node is Ignored', () async {
      final alice = VirtualBleAdapter('alice-id', 'Alice');
      final bob = VirtualBleAdapter('bob-id', 'Bob');

      // Distance = 200 (outside max range 120)
      MockBleMedium.instance.updateNodePosition('alice-id', 10, 10);
      MockBleMedium.instance.updateNodePosition('bob-id', 210, 10);

      await alice.startScanning();
      await bob.startAdvertising('Bob', 'bob-id');

      var discoveredAny = false;
      final sub = alice.discoveredDevices.listen((devices) {
        if (devices.isNotEmpty) {
          discoveredAny = true;
        }
      });

      // Wait 3 seconds to verify no discoveries happen
      await Future.delayed(const Duration(seconds: 3));
      expect(discoveredAny, isFalse);

      await sub.cancel();
      await alice.stopScanning();
      await bob.stopAdvertising();
      await alice.dispose();
      await bob.dispose();
    });

    test('Virtual GATT Connection and Bidirectional Data Routing', () async {
      final alice = VirtualBleAdapter('alice-id', 'Alice');
      final bob = VirtualBleAdapter('bob-id', 'Bob');

      MockBleMedium.instance.updateNodePosition('alice-id', 10, 10);
      MockBleMedium.instance.updateNodePosition('bob-id', 30, 10);

      final aliceConnEvents = <BleConnectionEvent>[];
      final bobConnEvents = <BleConnectionEvent>[];

      final aliceSub = alice.connectionStateChanges.listen(aliceConnEvents.add);
      final bobSub = bob.connectionStateChanges.listen(bobConnEvents.add);

      // Alice connects to Bob
      await alice.connectTo('bob-id');

      // Wait for connection to settle
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify connection state events on both sides
      expect(aliceConnEvents.any((e) => e.status == ConnectionStatus.connected && e.deviceId == 'bob-id'), isTrue);
      expect(bobConnEvents.any((e) => e.status == ConnectionStatus.connected && e.deviceId == 'alice-id'), isTrue);

      // Verify bidirectional data routing
      final bobReceivedData = Completer<Uint8List>();
      final bobDataSub = bob.incomingData.listen((packet) {
        expect(packet.deviceId, equals('alice-id'));
        bobReceivedData.complete(packet.data);
      });

      final testData = Uint8List.fromList([10, 20, 30, 40]);
      await alice.sendData('bob-id', testData);

      final received = await bobReceivedData.future.timeout(const Duration(seconds: 3));
      expect(received, equals(testData));

      // Disconnect
      await alice.disconnectFrom('bob-id');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(aliceConnEvents.last.status, equals(ConnectionStatus.disconnected));
      expect(bobConnEvents.last.status, equals(ConnectionStatus.disconnected));

      await aliceSub.cancel();
      await bobSub.cancel();
      await bobDataSub.cancel();
      await alice.dispose();
      await bob.dispose();
    });
  });
}
