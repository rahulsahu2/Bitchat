import 'package:isar/isar.dart';
import '../../../utils/hash_helper.dart';

part 'peer.g.dart';

@collection
class Peer {
  Id get id => fastHash(userId);

  @Index(unique: true, replace: true)
  late String userId;

  late String nickname;
  late int avatarColor;
  late String status;
  late String publicKey;
  
  late bool isTrusted;
  late bool isBlocked;
  late DateTime lastSeen;
  late int lastRssi;
  late int hops;
}
