import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:bitchat/core/services/providers.dart';
import 'package:bitchat/core/services/ble/mock_ble_service.dart';
import 'package:bitchat/core/services/ble/real_ble_service.dart';
import 'package:bitchat/core/services/database/database_service.dart';
import 'package:bitchat/core/services/database/schemas/user_identity.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;
  late DatabaseService db;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bitchat_providers_test');
    db = DatabaseService();
    await db.init(directoryPath: tempDir.path, name: 'providers_test_db');

    // Create a Riverpod container with overridden database provider to point to our test DB
    container = ProviderContainer(
      overrides: [
        databaseServiceProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Riverpod Providers Tests', () {
    test('UserIdentityNotifier creates and loads profile', () async {
      // 1. Initial state should be null (empty database)
      final identityInit = await container.read(userIdentityProvider.future);
      expect(identityInit, isNull);

      // 2. Create profile identity
      await container.read(userIdentityProvider.notifier).createUserIdentity('Alice', 0xFF4CAF50);

      // 3. Verify provider state updated
      final identityCreated = await container.read(userIdentityProvider.future);
      expect(identityCreated, isNotNull);
      expect(identityCreated!.nickname, equals('Alice'));
      expect(identityCreated.avatarColor, equals(0xFF4CAF50));
      expect(identityCreated.publicKey.isNotEmpty, isTrue);
      expect(identityCreated.privateKey.isNotEmpty, isTrue);

      // 4. Verify profile update
      await container.read(userIdentityProvider.notifier).updateProfile('Alice Updated', 'Offline', 0xFFFF9800);
      final identityUpdated = await container.read(userIdentityProvider.future);
      expect(identityUpdated, isNotNull);
      expect(identityUpdated!.nickname, equals('Alice Updated'));
      expect(identityUpdated.status, equals('Offline'));
      expect(identityUpdated.avatarColor, equals(0xFFFF9800));
    });

    test('BleServiceProvider dynamic implementation swapping', () async {
      // 1. Create own identity first (since MockBleService requires it)
      await container.read(userIdentityProvider.notifier).createUserIdentity('Alice', 0xFF4CAF50);

      // 2. Default state is simulated mode = true
      expect(container.read(simulationModeProvider), isTrue);
      var bleService = container.read(bleServiceProvider);
      expect(bleService, isA<MockBleService>());

      // 3. Swap simulation mode to false (Real BLE)
      container.read(simulationModeProvider.notifier).state = false;
      bleService = container.read(bleServiceProvider);
      expect(bleService, isA<RealBleService>());

      // Swap back
      container.read(simulationModeProvider.notifier).state = true;
      bleService = container.read(bleServiceProvider);
      expect(bleService, isA<MockBleService>());
    });
  });
}
