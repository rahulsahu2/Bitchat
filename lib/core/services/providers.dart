import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ble/ble_service.dart';
import 'ble/mock_ble_service.dart';
import 'ble/real_ble_service.dart';
import 'database/database_service.dart';
import 'database/schemas/chat.dart';
import 'database/schemas/message.dart';
import 'database/schemas/user_identity.dart';
import 'encryption/crypto_service.dart';
import '../../features/mesh/data/mesh_router.dart';
import '../../features/mesh/domain/mesh_packet.dart';
import 'package:uuid/uuid.dart';

// --- Core Service Providers ---

/// Provider for DatabaseService singleton.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  // Note: initialization is handled in main.dart before app run
  return service;
});

/// Simulation Mode Toggle (Developer settings).
/// Setting to true simulates a BLE mesh in memory, false runs real BLE hardware.
final simulationModeProvider = StateProvider<bool>((ref) => true);

/// Provider for the active BleService implementation.
final bleServiceProvider = Provider<BleService>((ref) {
  final isSim = ref.watch(simulationModeProvider);
  final db = ref.watch(databaseServiceProvider);

  if (isSim) {
    // Obtain nickname and userId synchronously if identity exists, fallback to defaults
    final identity = ref.watch(userIdentityProvider).valueOrNull;
    final userId = identity?.userId ?? 'local-user';
    final nickname = identity?.nickname ?? 'Me';
    return MockBleService(userId, nickname);
  } else {
    return RealBleService();
  }
});

// --- User Identity State Provider ---

/// Provider for managing local user identity and profile updates.
final userIdentityProvider = AsyncNotifierProvider<UserIdentityNotifier, UserIdentity?>(() {
  return UserIdentityNotifier();
});

class UserIdentityNotifier extends AsyncNotifier<UserIdentity?> {
  @override
  FutureOr<UserIdentity?> build() async {
    final db = ref.watch(databaseServiceProvider);
    return db.getUserIdentity();
  }

  /// Generates a new identity with curve25519 E2EE key pairs on first launch.
  Future<void> createUserIdentity(String nickname, int avatarColor) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      
      final keys = CryptoService.generateKeyPair();
      final pubKey = CryptoService.encodePublicKey(keys.publicKey);
      final privKey = CryptoService.encodePrivateKey(keys.privateKey);

      final identity = UserIdentity()
        ..userId = const Uuid().v4()
        ..nickname = nickname
        ..status = 'Hey! I am using BitChat Mesh.'
        ..avatarColor = avatarColor
        ..publicKey = pubKey
        ..privateKey = privKey;

      await db.saveUserIdentity(identity);
      return identity;
    });
  }

  /// Updates own profile information (nickname, status, avatar color).
  Future<void> updateProfile(String nickname, String status, int avatarColor) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);

      final updated = UserIdentity()
        ..userId = current.userId
        ..nickname = nickname
        ..status = status
        ..avatarColor = avatarColor
        ..publicKey = current.publicKey
        ..privateKey = current.privateKey;

      await db.saveUserIdentity(updated);
      return updated;
    });
  }
}

// --- Routing & Mesh Providers ---

/// Async Provider that resolves the initialized MeshRouter singleton.
final meshRouterStateProvider = AsyncNotifierProvider<MeshRouterNotifier, MeshRouter?>(() {
  return MeshRouterNotifier();
});

class MeshRouterNotifier extends AsyncNotifier<MeshRouter?> {
  @override
  FutureOr<MeshRouter?> build() async {
    final identity = ref.watch(userIdentityProvider).valueOrNull;
    if (identity == null) return null;

    final ble = ref.watch(bleServiceProvider);
    final db = ref.watch(databaseServiceProvider);

    final router = MeshRouter(bleService: ble, dbService: db);
    await router.init();

    ref.onDispose(() {
      router.dispose();
    });

    return router;
  }
}

// --- Neighbor & Scanning Streams ---

/// Watches active directly connected BLE neighbors.
final activeNeighborsProvider = StreamProvider<List<Neighbor>>((ref) {
  final routerState = ref.watch(meshRouterStateProvider);
  final router = routerState.valueOrNull;
  if (router == null) return Stream.value([]);

  final controller = StreamController<List<Neighbor>>();
  // Yield initial value immediately
  controller.add(router.activeNeighbors);

  final subscription = router.onNeighborsUpdated.listen((data) {
    if (!controller.isClosed) {
      controller.add(data);
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Watches active packets routed through the local node (for diagnostics graph visualization).
final routedPacketsProvider = StreamProvider<MeshPacket>((ref) {
  final router = ref.watch(meshRouterStateProvider).valueOrNull;
  if (router == null) return const Stream.empty();
  return router.onPacketRouted;
});

/// Watches the file transfer chunk assembly progress percentage (messageId -> progress value 0.0 to 1.0).
final chunkProgressProvider = StreamProvider<Map<String, double>>((ref) {
  final router = ref.watch(meshRouterStateProvider).valueOrNull;
  if (router == null) return Stream.value({});
  return router.onChunkProgress;
});

// --- Chats & Messaging Streams ---

/// Watches all active chats sorted by pinned status and message time in real-time.
final chatsStreamProvider = StreamProvider<List<Chat>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.watchChats();
});

/// Tracks the active chat opened by the user.
final activeChatIdProvider = StateProvider<String?>((ref) => null);

/// Watches messages for a specific chat thread, delivering chronological real-time list.
final messagesStreamProvider = StreamProvider.family<List<Message>, String>((ref, chatId) {
  final db = ref.watch(databaseServiceProvider);
  return db.watchMessagesForChat(chatId);
});
