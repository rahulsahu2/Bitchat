import 'package:isar/isar.dart';
import '../../../utils/hash_helper.dart';

part 'chat.g.dart';

@collection
class Chat {
  Id get id => fastHash(chatId);

  @Index(unique: true, replace: true)
  late String chatId; // Peer UUID for 1-to-1 chat, or Group UUID for group chat

  late String name;
  late bool isGroup;
  late int unreadCount;
  late String lastMessageText;
  late DateTime lastMessageTime;
  
  late bool isPinned;
  late bool isArchived;
}
