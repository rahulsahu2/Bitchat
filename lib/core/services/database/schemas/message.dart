import 'package:isar/isar.dart';
import '../../../utils/hash_helper.dart';

part 'message.g.dart';

@collection
class Message {
  Id get id => fastHash(messageId);

  @Index(unique: true, replace: true)
  late String messageId;

  @Index()
  late String chatId;

  late String senderId;
  late String text;

  @Index()
  late DateTime timestamp;

  late bool isSent;
  late bool isDelivered;
  late bool isRead;
  
  String? reaction; // Emoji reaction e.g. '👍', '❤️'
  String? mediaPath; // Local path to downloaded file/image/audio
  String? mediaType; // 'image', 'audio', 'video', 'file'
  String? replyToMessageId; // Points to another Message.messageId if this is a reply
}
