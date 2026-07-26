import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'schemas/user_identity.dart';
import 'schemas/peer.dart';
import 'schemas/chat.dart';
import 'schemas/message.dart';
import 'schemas/packet_history.dart';

class DatabaseService {
  late final Isar isar;

  /// Initializes the Isar instance and opens the necessary schemas.
  Future<void> init({String? directoryPath, String name = 'default'}) async {
    final String path;
    if (directoryPath != null) {
      path = directoryPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = dir.path;
    }

    isar = await Isar.open(
      [
        UserIdentitySchema,
        PeerSchema,
        ChatSchema,
        MessageSchema,
        PacketHistorySchema,
      ],
      directory: path,
      name: name,
    );
  }

  // --- User Identity Queries ---

  Future<UserIdentity?> getUserIdentity() async {
    return isar.userIdentitys.get(0);
  }

  Future<void> saveUserIdentity(UserIdentity identity) async {
    identity.id = 0; // Enforce single record
    await isar.writeTxn(() async {
      await isar.userIdentitys.put(identity);
    });
  }

  // --- Peer Queries ---

  Future<List<Peer>> getAllPeers() async {
    return isar.peers.where().sortByLastSeenDesc().findAll();
  }

  Future<Peer?> getPeer(String userId) async {
    return isar.peers.filter().userIdEqualTo(userId).findFirst();
  }

  Future<void> savePeer(Peer peer) async {
    await isar.writeTxn(() async {
      await isar.peers.put(peer);
    });
  }

  Future<void> deletePeer(String userId) async {
    final peer = await getPeer(userId);
    if (peer != null) {
      await isar.writeTxn(() async {
        await isar.peers.delete(peer.id);
      });
    }
  }

  Stream<List<Peer>> watchPeers() {
    return isar.peers.where().sortByLastSeenDesc().watch(fireImmediately: true);
  }

  // --- Chat Queries ---

  Future<List<Chat>> getAllChats() async {
    return isar.chats.where().sortByIsPinnedDesc().thenByLastMessageTimeDesc().findAll();
  }

  Future<Chat?> getChat(String chatId) async {
    return isar.chats.filter().chatIdEqualTo(chatId).findFirst();
  }

  Future<void> saveChat(Chat chat) async {
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
  }

  Future<void> deleteChat(String chatId) async {
    final chat = await getChat(chatId);
    if (chat != null) {
      await isar.writeTxn(() async {
        await isar.chats.delete(chat.id);
        // Clean up messages associated with this chat
        await isar.messages.filter().chatIdEqualTo(chatId).deleteAll();
      });
    }
  }

  Stream<List<Chat>> watchChats() {
    return isar.chats.where().sortByIsPinnedDesc().thenByLastMessageTimeDesc().watch(fireImmediately: true);
  }

  // --- Message Queries ---

  Future<List<Message>> getMessagesForChat(String chatId, {int limit = 50, int offset = 0}) async {
    return isar.messages
        .filter()
        .chatIdEqualTo(chatId)
        .sortByTimestampDesc()
        .offset(offset)
        .limit(limit)
        .findAll()
        .then((list) => list.reversed.toList()); // Return in chronological order
  }

  Future<Message?> getMessage(String messageId) async {
    return isar.messages.filter().messageIdEqualTo(messageId).findFirst();
  }

  Future<void> saveMessage(Message message) async {
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
  }

  Future<void> deleteMessage(String messageId) async {
    final msg = await getMessage(messageId);
    if (msg != null) {
      await isar.writeTxn(() async {
        await isar.messages.delete(msg.id);
      });
    }
  }

  Stream<List<Message>> watchMessagesForChat(String chatId) async* {
    yield await getMessagesForChat(chatId, limit: 100);

    yield* isar.messages
        .filter()
        .chatIdEqualTo(chatId)
        .watch()
        .asyncMap((_) => getMessagesForChat(chatId, limit: 100));
  }

  // --- Packet History Queries ---

  Future<bool> isPacketProcessed(String packetId) async {
    final match = await isar.packetHistorys.filter().packetIdEqualTo(packetId).findFirst();
    return match != null;
  }

  Future<void> markPacketProcessed(String packetId) async {
    final history = PacketHistory()
      ..packetId = packetId
      ..timestamp = DateTime.now();
    await isar.writeTxn(() async {
      await isar.packetHistorys.put(history);
    });
  }

  Future<void> pruneOldPackets(DateTime before) async {
    await isar.writeTxn(() async {
      await isar.packetHistorys.filter().timestampLessThan(before).deleteAll();
    });
  }

  /// Clears the entire database (e.g. for factory reset).
  Future<void> clearAll() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  }
}
