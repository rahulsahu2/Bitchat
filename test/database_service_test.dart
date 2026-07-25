import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:bitchat/core/services/database/database_service.dart';
import 'package:bitchat/core/services/database/schemas/user_identity.dart';
import 'package:bitchat/core/services/database/schemas/peer.dart';
import 'package:bitchat/core/services/database/schemas/chat.dart';
import 'package:bitchat/core/services/database/schemas/message.dart';

void main() {
  late DatabaseService db;
  late Directory tempDir;

  setUpAll(() async {
    // Initialize Isar core binaries for testing environment
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bitchat_db_test');
    db = DatabaseService();
    await db.init(directoryPath: tempDir.path);
  });

  tearDown(() async {
    await db.isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Database Service Tests', () {
    test('Save and Get User Identity', () async {
      final identity = UserIdentity()
        ..userId = 'user-123'
        ..nickname = 'Alice'
        ..status = 'Online'
        ..avatarColor = 0xFF4CAF50
        ..publicKey = 'pubkey123'
        ..privateKey = 'privkey123';

      await db.saveUserIdentity(identity);

      final retrieved = await db.getUserIdentity();
      expect(retrieved, isNotNull);
      expect(retrieved!.userId, equals('user-123'));
      expect(retrieved.nickname, equals('Alice'));
      expect(retrieved.status, equals('Online'));
      expect(retrieved.avatarColor, equals(0xFF4CAF50));
      expect(retrieved.publicKey, equals('pubkey123'));
      expect(retrieved.privateKey, equals('privkey123'));
    });

    test('Peer CRUD operations', () async {
      final peer = Peer()
        ..userId = 'peer-456'
        ..nickname = 'Bob'
        ..status = 'Hey there!'
        ..avatarColor = 0xFF2196F3
        ..publicKey = 'bob_pubkey'
        ..isTrusted = true
        ..isBlocked = false
        ..lastSeen = DateTime.now()
        ..lastRssi = -55
        ..hops = 1;

      await db.savePeer(peer);

      final retrieved = await db.getPeer('peer-456');
      expect(retrieved, isNotNull);
      expect(retrieved!.nickname, equals('Bob'));
      expect(retrieved.isTrusted, isTrue);

      final allPeers = await db.getAllPeers();
      expect(allPeers.length, equals(1));

      // Test delete
      await db.deletePeer('peer-456');
      final afterDelete = await db.getPeer('peer-456');
      expect(afterDelete, isNull);
    });

    test('Chat and Message Operations', () async {
      final chat = Chat()
        ..chatId = 'chat-789'
        ..name = 'Bob'
        ..isGroup = false
        ..unreadCount = 2
        ..lastMessageText = 'Hello Alice'
        ..lastMessageTime = DateTime.now()
        ..isPinned = true
        ..isArchived = false;

      await db.saveChat(chat);

      final retrievedChat = await db.getChat('chat-789');
      expect(retrievedChat, isNotNull);
      expect(retrievedChat!.name, equals('Bob'));
      expect(retrievedChat.unreadCount, equals(2));
      expect(retrievedChat.isPinned, isTrue);

      final msg1 = Message()
        ..messageId = 'msg-1'
        ..chatId = 'chat-789'
        ..senderId = 'peer-456'
        ..text = 'Hello Alice'
        ..timestamp = DateTime.now().subtract(const Duration(minutes: 1))
        ..isSent = true
        ..isDelivered = true
        ..isRead = false;

      final msg2 = Message()
        ..messageId = 'msg-2'
        ..chatId = 'chat-789'
        ..senderId = 'user-123'
        ..text = 'Hey Bob!'
        ..timestamp = DateTime.now()
        ..isSent = true
        ..isDelivered = false
        ..isRead = false;

      await db.saveMessage(msg1);
      await db.saveMessage(msg2);

      final messages = await db.getMessagesForChat('chat-789');
      expect(messages.length, equals(2));
      expect(messages[0].messageId, equals('msg-1'));
      expect(messages[1].messageId, equals('msg-2'));

      // Check specific message
      final fetchedMsg = await db.getMessage('msg-2');
      expect(fetchedMsg, isNotNull);
      expect(fetchedMsg!.text, equals('Hey Bob!'));

      // Delete message
      await db.deleteMessage('msg-1');
      final messagesAfterDelete = await db.getMessagesForChat('chat-789');
      expect(messagesAfterDelete.length, equals(1));
      expect(messagesAfterDelete[0].messageId, equals('msg-2'));
    });

    test('Packet history and Deduplication', () async {
      const packetId = 'packet-999';

      var isProcessed = await db.isPacketProcessed(packetId);
      expect(isProcessed, isFalse);

      await db.markPacketProcessed(packetId);
      isProcessed = await db.isPacketProcessed(packetId);
      expect(isProcessed, isTrue);

      // Prune old packets
      final beforeTime = DateTime.now().add(const Duration(minutes: 5));
      await db.pruneOldPackets(beforeTime);

      isProcessed = await db.isPacketProcessed(packetId);
      expect(isProcessed, isFalse); // Should be pruned!
    });
  });
}
