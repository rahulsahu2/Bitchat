import 'package:isar/isar.dart';
import '../../../utils/hash_helper.dart';

part 'packet_history.g.dart';

@collection
class PacketHistory {
  Id get id => fastHash(packetId);

  @Index(unique: true, replace: true)
  late String packetId;

  @Index()
  late DateTime timestamp;
}
