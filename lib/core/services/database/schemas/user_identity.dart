import 'package:isar/isar.dart';

part 'user_identity.g.dart';

@collection
class UserIdentity {
  Id id = 0; // Always 0 as there is only one own identity

  @Index(unique: true)
  late String userId;

  late String nickname;
  late int avatarColor;
  late String status;
  late String publicKey;
  late String privateKey;
}
