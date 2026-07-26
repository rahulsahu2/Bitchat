import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'mock_ble_service.dart';
import 'package:bitchat/core/services/database/database_service.dart';
import 'package:bitchat/core/services/database/schemas/user_identity.dart';
import 'package:bitchat/core/services/database/schemas/peer.dart';
import 'package:bitchat/core/services/encryption/crypto_service.dart';
import 'package:bitchat/features/mesh/data/mesh_router.dart';

void main() {
  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() {
    MockBleMedium.instance.clear();
  });

  group('Mesh Routing & Integration Tests', () {
    test('Chain Routing test: Alice <-> Bob <-> Charlie', () async {
      // Create three directories for databases
      final tempDirAlice = await Directory.systemTemp.createTemp('db_alice');
      final tempDirBob = await Directory.systemTemp.createTemp('db_bob');
      final tempDirCharlie = await Directory.systemTemp.createTemp('db_charlie');

      // 1. Initialize databases
      final dbAlice = DatabaseService();
      final dbBob = DatabaseService();
      final dbCharlie = DatabaseService();

      await dbAlice.init(directoryPath: tempDirAlice.path, name: 'alice');
      await dbBob.init(directoryPath: tempDirBob.path, name: 'bob');
      await dbCharlie.init(directoryPath: tempDirCharlie.path, name: 'charlie');

      // Generate key pairs for everyone
      final keysAlice = CryptoService.generateKeyPair();
      final keysBob = CryptoService.generateKeyPair();
      final keysCharlie = CryptoService.generateKeyPair();

      // Save User Identities
      await dbAlice.saveUserIdentity(
        UserIdentity()
          ..userId = 'alice-id'
          ..nickname = 'Alice'
          ..status = 'Online'
          ..avatarColor = 0xFF4CAF50
          ..publicKey = CryptoService.encodePublicKey(keysAlice.publicKey)
          ..privateKey = CryptoService.encodePrivateKey(keysAlice.privateKey),
      );

      await dbBob.saveUserIdentity(
        UserIdentity()
          ..userId = 'bob-id'
          ..nickname = 'Bob'
          ..status = 'Online'
          ..avatarColor = 0xFF2196F3
          ..publicKey = CryptoService.encodePublicKey(keysBob.publicKey)
          ..privateKey = CryptoService.encodePrivateKey(keysBob.privateKey),
      );

      await dbCharlie.saveUserIdentity(
        UserIdentity()
          ..userId = 'charlie-id'
          ..nickname = 'Charlie'
          ..status = 'Online'
          ..avatarColor = 0xFFFF9800
          ..publicKey = CryptoService.encodePublicKey(keysCharlie.publicKey)
          ..privateKey = CryptoService.encodePrivateKey(keysCharlie.privateKey),
      );

      // Distribute public keys into peers database (Simulates QR pairing or identity exchanges)
      await dbAlice.savePeer(
        Peer()
          ..userId = 'bob-id'
          ..nickname = 'Bob'
          ..status = 'Online'
          ..avatarColor = 0xFF2196F3
          ..publicKey = CryptoService.encodePublicKey(keysBob.publicKey)
          ..isTrusted = true
          ..isBlocked = false
          ..lastSeen = DateTime.now()
          ..lastRssi = -50
          ..hops = 1,
      );

      await dbAlice.savePeer(
        Peer()
          ..userId = 'charlie-id'
          ..nickname = 'Charlie'
          ..status = 'Online'
          ..avatarColor = 0xFFFF9800
          ..publicKey = CryptoService.encodePublicKey(keysCharlie.publicKey)
          ..isTrusted = true
          ..isBlocked = false
          ..lastSeen = DateTime.now()
          ..lastRssi = -100
          ..hops = 2,
      );

      await dbBob.savePeer(
        Peer()
          ..userId = 'alice-id'
          ..nickname = 'Alice'
          ..status = 'Online'
          ..avatarColor = 0xFF4CAF50
          ..publicKey = CryptoService.encodePublicKey(keysAlice.publicKey)
          ..isTrusted = true
          ..isBlocked = false
          ..lastSeen = DateTime.now()
          ..lastRssi = -50
          ..hops = 1,
      );

      await dbBob.savePeer(
        Peer()
          ..userId = 'charlie-id'
          ..nickname = 'Charlie'
          ..status = 'Online'
          ..avatarColor = 0xFFFF9800
          ..publicKey = CryptoService.encodePublicKey(keysCharlie.publicKey)
          ..isTrusted = true
          ..isBlocked = false
          ..lastSeen = DateTime.now()
          ..lastRssi = -50
          ..hops = 1,
      );

      await dbCharlie.savePeer(
        Peer()
          ..userId = 'bob-id'
          ..nickname = 'Bob'
          ..status = 'Online'
          ..avatarColor = 0xFF2196F3
          ..publicKey = CryptoService.encodePublicKey(keysBob.publicKey)
          ..isTrusted = true
          ..isBlocked = false
          ..lastSeen = DateTime.now()
          ..lastRssi = -50
          ..hops = 1,
      );

      await dbCharlie.savePeer(
        Peer()
          ..userId = 'alice-id'
          ..nickname = 'Alice'
          ..status = 'Online'
          ..avatarColor = 0xFF4CAF50
          ..publicKey = CryptoService.encodePublicKey(keysAlice.publicKey)
          ..isTrusted = true
          ..isBlocked = false
          ..lastSeen = DateTime.now()
          ..lastRssi = -100
          ..hops = 2,
      );

      // 2. Setup simulated BLE adapters
      final bleAlice = VirtualBleAdapter('alice-id', 'Alice');
      final bleBob = VirtualBleAdapter('bob-id', 'Bob');
      final bleCharlie = VirtualBleAdapter('charlie-id', 'Charlie');

      // Configure positions: Alice is close to Bob, Bob is close to Charlie. Alice and Charlie are far apart.
      MockBleMedium.instance.updateNodePosition('alice-id', 10, 10);
      MockBleMedium.instance.updateNodePosition('bob-id', 80, 10);      // Distance Alice-Bob = 70
      MockBleMedium.instance.updateNodePosition('charlie-id', 180, 10);  // Distance Bob-Charlie = 100, Alice-Charlie = 170

      // Initialize routers
      final routerAlice = MeshRouter(bleService: bleAlice, dbService: dbAlice);
      final routerBob = MeshRouter(bleService: bleBob, dbService: dbBob);
      final routerCharlie = MeshRouter(bleService: bleCharlie, dbService: dbCharlie);

      await routerAlice.init();
      await routerBob.init();
      await routerCharlie.init();

      // Establish connections: Alice <-> Bob, Bob <-> Charlie
      await bleAlice.connectTo('bob-id');
      await bleBob.connectTo('charlie-id');

      await Future.delayed(const Duration(milliseconds: 600));
      debugPrint('DEBUG: Alice neighbors: ${routerAlice.activeNeighbors.map((n) => "${n.userId}:${n.isConnected}").toList()}');
      debugPrint('DEBUG: Charlie neighbors: ${routerCharlie.activeNeighbors.map((n) => "${n.userId}:${n.isConnected}").toList()}');

      expect(routerAlice.activeNeighbors.any((n) => n.userId == 'bob-id' && n.isConnected), isTrue);
      expect(routerCharlie.activeNeighbors.any((n) => n.userId == 'bob-id' && n.isConnected), isTrue);
      // Verify Alice does NOT see Charlie as direct neighbor
      expect(routerAlice.activeNeighbors.any((n) => n.userId == 'charlie-id'), isFalse);

      // 3. Test multi-hop message transmission
      final charlieMsgCompleter = Completer<String>();
      final charlieSub = routerCharlie.onNewMessage.listen((msg) {
        if (msg.senderId == 'alice-id') {
          charlieMsgCompleter.complete(msg.text);
        }
      });

      // Send message from Alice to Charlie. This triggers route discovery RREQ/RREP first.
      final sendResult = await routerAlice.sendMessage('charlie-id', 'Hello Charlie from Alice! Hello!');
      expect(sendResult, isTrue);

      // Verify Charlie received and decrypted the message correctly
      final receivedText = await charlieMsgCompleter.future.timeout(const Duration(seconds: 8));
      expect(receivedText, equals('Hello Charlie from Alice! Hello!'));

      // Wait a moment for ACK to travel back and update Alice's DB
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify that Alice cached the route correctly: Alice -> Bob -> Charlie
      final cachedRoute = routerAlice.routeCache['charlie-id'];
      expect(cachedRoute, isNotNull);
      expect(cachedRoute, equals(['alice-id', 'bob-id', 'charlie-id']));

      // Verify Alice received the ACK and marked the message as delivered
      final aliceMessages = await dbAlice.getMessagesForChat('charlie-id');
      expect(aliceMessages.isNotEmpty, isTrue);
      expect(aliceMessages.last.isDelivered, isTrue);

      // Clean up
      await charlieSub.cancel();
      await routerAlice.dispose();
      await routerBob.dispose();
      await routerCharlie.dispose();
      await bleAlice.dispose();
      await bleBob.dispose();
      await bleCharlie.dispose();
      await dbAlice.isar.close();
      await dbBob.isar.close();
      await dbCharlie.isar.close();

      await tempDirAlice.delete(recursive: true);
      await tempDirBob.delete(recursive: true);
      await tempDirCharlie.delete(recursive: true);
    });
  });
}
