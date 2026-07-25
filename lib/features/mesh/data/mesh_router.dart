import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/ble/ble_service.dart';
import '../../../core/services/database/database_service.dart';
import '../../../core/services/database/schemas/chat.dart';
import '../../../core/services/database/schemas/message.dart';
import '../../../core/services/database/schemas/peer.dart';
import '../../../core/services/database/schemas/user_identity.dart';
import '../../../core/services/encryption/crypto_service.dart';
import '../domain/mesh_packet.dart';

/// Represents a directly connected BLE neighbor.
class Neighbor {
  final String userId;
  final String nickname;
  int rssi;
  DateTime lastSeen;
  bool isConnected;

  Neighbor({
    required this.userId,
    required this.nickname,
    required this.rssi,
    required this.lastSeen,
    required this.isConnected,
  });
}

/// Tracks details of chunked message reassembly.
class ChunkAssembler {
  final String messageId;
  final int totalChunks;
  final Map<int, String> chunks = {}; // chunkIndex -> encrypted base64 payload chunk
  final DateTime timestamp = DateTime.now();

  ChunkAssembler(this.messageId, this.totalChunks);

  bool get isComplete => chunks.length == totalChunks;

  String assemble() {
    final buffer = StringBuffer();
    for (var i = 0; i < totalChunks; i++) {
      buffer.write(chunks[i]);
    }
    return buffer.toString();
  }
}

/// Core routing engine that operates the Bluetooth Mesh Network.
class MeshRouter {
  final BleService bleService;
  final DatabaseService dbService;

  UserIdentity? _identity;
  UserIdentity? get identity => _identity;
  bool _isPairingEnabled = true;

  // Active neighbors
  final Map<String, Neighbor> _neighbors = {};
  
  // Route cache: destinationUserId -> Full hops path [Alice, Bob, Charlie]
  final Map<String, List<String>> _routeCache = {};

  // Pending RREQ completers: destinationUserId -> completer
  final Map<String, Completer<List<String>>> _rreqCompleters = {};

  // Chunk assembly caches: messageId -> ChunkAssembler
  final Map<String, ChunkAssembler> _assemblers = {};

  // Timers and subscriptions
  Timer? _heartbeatTimer;
  Timer? _maintenanceTimer;
  StreamSubscription? _discoverySub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _dataSub;

  // UI Event Controllers
  final _messageController = StreamController<Message>.broadcast();
  final _neighborController = StreamController<List<Neighbor>>.broadcast();
  final _routedPacketController = StreamController<MeshPacket>.broadcast();
  final _chunkProgressController = StreamController<Map<String, double>>.broadcast();

  MeshRouter({
    required this.bleService,
    required this.dbService,
  });

  Stream<Message> get onNewMessage => _messageController.stream;
  Stream<List<Neighbor>> get onNeighborsUpdated => _neighborController.stream;
  Stream<MeshPacket> get onPacketRouted => _routedPacketController.stream;
  Stream<Map<String, double>> get onChunkProgress => _chunkProgressController.stream;

  List<Neighbor> get activeNeighbors => _neighbors.values.toList();
  Map<String, List<String>> get routeCache => Map.unmodifiable(_routeCache);

  /// Initializes the router, loads own keys, and begins scans/advertisements.
  Future<void> init() async {
    _identity = await dbService.getUserIdentity();
    if (_identity == null) {
      throw Exception('No User Identity generated yet. Please create profile first.');
    }

    // Hook BLE streams
    _discoverySub = bleService.discoveredDevices.listen(_handleDiscoveredDevices);
    _connectionSub = bleService.connectionStateChanges.listen(_handleConnectionEvent);
    _dataSub = bleService.incomingData.listen(_handleIncomingRawData);

    // Setup periodic heartbeats (link maintenance)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) => _broadcastHeartbeat());

    // Setup network maintenance (pruning old packets/routes)
    _maintenanceTimer = Timer.periodic(const Duration(minutes: 5), (_) => _runMaintenance());

    // Start scanning and advertising if pairing is enabled
    if (_isPairingEnabled) {
      await bleService.startScanning();
      await bleService.startAdvertising(_identity!.nickname, _identity!.userId);
    }
  }

  void setPairingMode(bool enabled) {
    if (_isPairingEnabled == enabled) return;
    _isPairingEnabled = enabled;
    if (enabled) {
      bleService.startScanning();
      bleService.startAdvertising(_identity!.nickname, _identity!.userId);
    } else {
      bleService.stopScanning();
      bleService.stopAdvertising();
      // Disconnect all except trusted
      final peersToDisconnect = <String>[];
      _neighbors.forEach((peerId, neighbor) {
        if (neighbor.isConnected) {
          peersToDisconnect.add(peerId);
        }
      });
      for (final p in peersToDisconnect) {
        bleService.disconnectFrom(p);
      }
    }
  }

  // --- Send Message API ---

  /// Encrypts, signs, fragments (if large), and routes a message to a destination node.
  Future<bool> sendMessage(
    String destinationUserId,
    String text, {
    String? mediaPath,
    String? mediaType,
    String? replyToMessageId,
  }) async {
    if (_identity == null) return false;

    // 1. Resolve route
    final path = await _resolveRoute(destinationUserId);
    final bool useFloodFallback = path.isEmpty;

    // 2. Encrypt Payload (E2EE)
    final peer = await dbService.getPeer(destinationUserId);
    if (peer == null) {
      debugPrint('Cannot send message: Destination peer public key not found.');
      return false;
    }

    final ownPrivKey = CryptoService.decodePrivateKey(_identity!.privateKey);
    final peerPubKey = CryptoService.decodePublicKey(peer.publicKey);
    final sharedSecret = CryptoService.deriveSharedSecret(ownPrivKey, peerPubKey);

    // Prepare packet body
    final messageId = const Uuid().v4();
    final messageBody = {
      'messageId': messageId,
      'text': text,
      'mediaPath': mediaPath,
      'mediaType': mediaType,
      'replyToMessageId': replyToMessageId,
    };
    final serializedBody = utf8.encode(jsonEncode(messageBody));
    
    // Encrypt
    final iv = CryptoService.generateKeyPair().publicKey.Q!.getEncoded(false).sublist(0, 12); // Use random 96-bit bytes as IV
    final encryptedBytes = CryptoService.encryptAesGcm(Uint8List.fromList(serializedBody), sharedSecret, iv);

    final payloadJson = {
      'ciphertext': base64Encode(encryptedBytes),
      'iv': base64Encode(iv),
    };
    final payloadString = jsonEncode(payloadJson);
    final payloadBase64 = base64Encode(utf8.encode(payloadString));

    // Sign payload
    final signatureBytes = CryptoService.sign(utf8.encode(payloadBase64), ownPrivKey);
    final signatureBase64 = base64Encode(signatureBytes);

    // 3. Chunk payload if it exceeds maximum BLE packet safe size (approx 350 bytes base64 payload size)
    const int maxChunkSize = 300;
    final totalLength = payloadBase64.length;
    final totalChunks = (totalLength / maxChunkSize).ceil();

    final List<MeshPacket> packets = [];
    for (var i = 0; i < totalChunks; i++) {
      final start = i * maxChunkSize;
      final end = (start + maxChunkSize) > totalLength ? totalLength : (start + maxChunkSize);
      final chunkPayload = payloadBase64.substring(start, end);

      final packet = MeshPacket(
        id: const Uuid().v4(),
        senderId: _identity!.userId,
        receiverId: destinationUserId,
        type: 'MSG',
        ttl: 7,
        hopCount: 0,
        payload: chunkPayload,
        signature: signatureBase64, // Keep signature of the full message to verify integrity of combined payload
        chunkIndex: i,
        totalChunks: totalChunks,
        path: [_identity!.userId],
      );
      packets.add(packet);
    }

    // 4. Save message to DB as "sending" state
    final dbMsg = Message()
      ..messageId = messageId
      ..chatId = destinationUserId
      ..senderId = _identity!.userId
      ..text = text
      ..timestamp = DateTime.now()
      ..isSent = true
      ..isDelivered = false
      ..isRead = true // Read by own self
      ..mediaPath = mediaPath
      ..mediaType = mediaType
      ..replyToMessageId = replyToMessageId;

    await dbService.saveMessage(dbMsg);
    
    // Save/update Chat metadata
    var chat = await dbService.getChat(destinationUserId);
    if (chat == null) {
      chat = Chat()
        ..chatId = destinationUserId
        ..name = peer.nickname
        ..isGroup = false
        ..unreadCount = 0
        ..isPinned = false
        ..isArchived = false;
    }
    chat.lastMessageText = text.isNotEmpty ? text : (mediaType ?? 'Media');
    chat.lastMessageTime = DateTime.now();
    await dbService.saveChat(chat);

    // 5. Send the packets
    var sentSuccessful = true;
    for (final pkt in packets) {
      final result = await _routePacket(pkt, path: path, useFloodFallback: useFloodFallback);
      if (!result) {
        sentSuccessful = false;
      }
    }
    return sentSuccessful;
  }

  // --- BLE Event Handlers ---

  void _handleDiscoveredDevices(List<BleDevice> devices) {
    for (final dev in devices) {
      final isNew = !_neighbors.containsKey(dev.id);
      
      // Update/add to neighbor table
      final existing = _neighbors[dev.id];
      _neighbors[dev.id] = Neighbor(
        userId: dev.id,
        nickname: dev.name,
        rssi: dev.rssi,
        lastSeen: dev.lastSeen,
        isConnected: existing?.isConnected ?? false,
      );

      if (isNew) {
        _neighborController.add(_neighbors.values.toList());
      }

      // Auto-connect pairing algorithm
      if (_isPairingEnabled && !(existing?.isConnected ?? false)) {
        // Break connection race conditions: Alphabetically larger UUID initiates connection
        if (_identity != null && _identity!.userId.compareTo(dev.id) > 0) {
          bleService.connectTo(dev.id);
        }
      }
    }
  }

  void _handleConnectionEvent(BleConnectionEvent event) async {
    debugPrint('DEBUG [${_identity?.userId}]: _handleConnectionEvent for ${event.deviceId} with status ${event.status}');
    var neighbor = _neighbors[event.deviceId];
    if (neighbor == null && event.status == ConnectionStatus.connected) {
      debugPrint('DEBUG [${_identity?.userId}]: Neighbor ${event.deviceId} is null, fetching from DB...');
      final peer = await dbService.getPeer(event.deviceId);
      debugPrint('DEBUG [${_identity?.userId}]: DB result for ${event.deviceId}: ${peer?.nickname}');
      neighbor = Neighbor(
        userId: event.deviceId,
        nickname: peer?.nickname ?? (event.deviceId.length > 5 ? event.deviceId.substring(0, 5) : event.deviceId),
        rssi: peer?.lastRssi ?? -80,
        lastSeen: DateTime.now(),
        isConnected: true,
      );
      _neighbors[event.deviceId] = neighbor;
    }

    if (neighbor != null) {
      neighbor.isConnected = event.status == ConnectionStatus.connected;
      if (!neighbor.isConnected) {
        neighbor.lastSeen = DateTime.now();
      }
      _neighborController.add(_neighbors.values.toList());

      if (event.status == ConnectionStatus.connected) {
        debugPrint('DEBUG [${_identity?.userId}]: Exchanging identity with ${event.deviceId}');
        _sendIdentityDetails(event.deviceId);
      } else {
        _routeCache.removeWhere((dest, path) => path.contains(event.deviceId));
      }
    }
  }

  void _handleIncomingRawData(BleDataPacket rawPacket) async {
    try {
      final packet = MeshPacket.fromBytes(rawPacket.data);
      _routedPacketController.add(packet);

      // Flood protection: drop if already processed
      final isDuplicate = await dbService.isPacketProcessed(packet.id);
      if (isDuplicate) return;

      await dbService.markPacketProcessed(packet.id);

      // Packet processing switch
      switch (packet.type) {
        case 'HEARTBEAT':
          _processHeartbeat(packet, rawPacket.deviceId);
          break;
        case 'RREQ':
          _processRreq(packet);
          break;
        case 'RREP':
          _processRrep(packet);
          break;
        case 'MSG':
          _processMsg(packet);
          break;
        case 'ACK':
          _processAck(packet);
          break;
        case 'TYPING':
          _processTyping(packet);
          break;
      }
    } catch (e) {
      debugPrint('Error decoding incoming mesh packet: $e');
    }
  }

  // --- Cryptographic & Routing Processing ---

  void _sendIdentityDetails(String deviceId) async {
    if (_identity == null) return;
    
    // We send our profile detail (UserId, Nickname, Public Key)
    final profile = {
      'userId': _identity!.userId,
      'nickname': _identity!.nickname,
      'publicKey': _identity!.publicKey,
    };
    final jsonStr = jsonEncode(profile);
    
    final packet = MeshPacket(
      id: const Uuid().v4(),
      senderId: _identity!.userId,
      receiverId: deviceId,
      type: 'HEARTBEAT', // Use Heartbeat packet type to declare profile details
      ttl: 1,
      hopCount: 0,
      payload: jsonStr,
      signature: '',
      path: [_identity!.userId],
    );

    bleService.sendData(deviceId, packet.toBytes());
  }

  void _processHeartbeat(MeshPacket packet, String sourceDeviceId) async {
    try {
      final Map<String, dynamic> profile = jsonDecode(packet.payload);
      final String peerId = profile['userId'];
      final String nickname = profile['nickname'];
      final String? pubKey = profile['publicKey'];

      // Add to Database Peers collection
      var peer = await dbService.getPeer(peerId);
      final isNewPeer = peer == null;
      if (peer == null) {
        peer = Peer()
          ..userId = peerId
          ..publicKey = pubKey ?? ''
          ..isTrusted = false // Defaults to untrusted until pairing verification
          ..isBlocked = false;
      }
      peer.nickname = nickname;
      peer.status = 'Online';
      peer.lastSeen = DateTime.now();
      peer.lastRssi = _neighbors[sourceDeviceId]?.rssi ?? -80;
      peer.hops = packet.hopCount + 1;
      await dbService.savePeer(peer);

      // Trigger diagnostics refresh if peer was new
      if (isNewPeer) {
        _neighborController.add(_neighbors.values.toList());
      }
    } catch (_) {
      // Direct text fallback for simple legacy heartbeats
      final peer = await dbService.getPeer(packet.senderId);
      if (peer != null) {
        peer.lastSeen = DateTime.now();
        await dbService.savePeer(peer);
      }
    }
  }

  void _processRreq(MeshPacket packet) async {
    if (_identity == null) return;

    if (packet.receiverId == _identity!.userId) {
      // We are target! Send Route Reply (RREP)
      final rrep = MeshPacket(
        id: const Uuid().v4(),
        senderId: _identity!.userId,
        receiverId: packet.senderId,
        type: 'RREP',
        ttl: 7,
        hopCount: 0,
        payload: '',
        signature: '',
        path: List<String>.from(packet.path.reversed)..insert(0, _identity!.userId),
      );
      // Send back along the reverse path
      _routePacket(rrep);
    } else {
      // Forward the request if TTL permits
      if (packet.ttl > 1) {
        final forwarded = packet.copyWith(
          ttl: packet.ttl - 1,
          hopCount: packet.hopCount + 1,
          path: List<String>.from(packet.path)..add(_identity!.userId),
        );
        _floodPacket(forwarded);
      }
    }
  }

  void _processRrep(MeshPacket packet) async {
    if (_identity == null) return;

    if (packet.receiverId == _identity!.userId) {
      // Received the path reply!
      final fullPath = List<String>.from(packet.path.reversed);
      _routeCache[packet.senderId] = fullPath;

      // Complete any pending future waiting for this path
      final comp = _rreqCompleters.remove(packet.senderId);
      if (comp != null && !comp.isCompleted) {
        comp.complete(fullPath);
      }
    } else {
      // Forward back unicast along path
      _routePacket(packet, path: packet.path);
    }
  }

  void _processMsg(MeshPacket packet) async {
    if (_identity == null) return;

    if (packet.receiverId == _identity!.userId) {
      // We are the destination!
      // 1. Fragment Assembly
      var assembler = _assemblers[packet.signature];
      if (assembler == null) {
        assembler = ChunkAssembler(packet.signature, packet.totalChunks);
        _assemblers[packet.signature] = assembler;
      }
      assembler.chunks[packet.chunkIndex] = packet.payload;

      // Notify progress to UI
      final progress = assembler.chunks.length / assembler.totalChunks;
      _chunkProgressController.add({packet.signature: progress});

      if (!assembler.isComplete) {
        return; // Wait for remaining fragments
      }

      // Reassembled successfully!
      _assemblers.remove(packet.signature);
      final fullPayloadBase64 = assembler.assemble();

      // 2. Cryptographic signature check
      final peer = await dbService.getPeer(packet.senderId);
      if (peer == null) {
        debugPrint('Dropping message: Unknown sender, no public key.');
        return;
      }

      final peerPubKey = CryptoService.decodePublicKey(peer.publicKey);
      final signatureBytes = base64Decode(packet.signature);
      final isSignatureValid = CryptoService.verify(utf8.encode(fullPayloadBase64), signatureBytes, peerPubKey);
      if (!isSignatureValid) {
        debugPrint('Dropping message: Digital signature verification failed.');
        return;
      }

      // 3. Decrypt Payload
      final ownPrivKey = CryptoService.decodePrivateKey(_identity!.privateKey);
      final sharedSecret = CryptoService.deriveSharedSecret(ownPrivKey, peerPubKey);

      final payloadJson = jsonDecode(utf8.decode(base64Decode(fullPayloadBase64))) as Map<String, dynamic>;
      final ciphertext = base64Decode(payloadJson['ciphertext']);
      final iv = base64Decode(payloadJson['iv']);

      final decryptedBytes = CryptoService.decryptAesGcm(ciphertext, sharedSecret, iv);
      final decryptedBody = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;

      final messageId = decryptedBody['messageId'] as String;
      final text = decryptedBody['text'] as String;
      final mediaPath = decryptedBody['mediaPath'] as String?;
      final mediaType = decryptedBody['mediaType'] as String?;
      final replyToId = decryptedBody['replyToMessageId'] as String?;

      // 4. Save to Database
      final msg = Message()
        ..messageId = messageId
        ..chatId = packet.senderId
        ..senderId = packet.senderId
        ..text = text
        ..timestamp = DateTime.now()
        ..isSent = true
        ..isDelivered = true
        ..isRead = false // Unread by user
        ..mediaPath = mediaPath
        ..mediaType = mediaType
        ..replyToMessageId = replyToId;

      await dbService.saveMessage(msg);

      // Update Chat
      var chat = await dbService.getChat(packet.senderId);
      if (chat == null) {
        chat = Chat()
          ..chatId = packet.senderId
          ..name = peer.nickname
          ..isGroup = false
          ..unreadCount = 0
          ..lastMessageText = ''
          ..lastMessageTime = DateTime.now()
          ..isPinned = false
          ..isArchived = false;
      }
      chat.unreadCount += 1;
      chat.lastMessageText = text.isNotEmpty ? text : (mediaType ?? 'Media');
      chat.lastMessageTime = DateTime.now();
      await dbService.saveChat(chat);

      // Emit new message event to Riverpod listeners
      _messageController.add(msg);

      // 5. Send Acknowledgement (ACK)
      final ack = MeshPacket(
        id: const Uuid().v4(),
        senderId: _identity!.userId,
        receiverId: packet.senderId,
        type: 'ACK',
        ttl: 7,
        hopCount: 0,
        payload: messageId, // Payload is the acknowledged message ID
        signature: '',
        path: [_identity!.userId],
      );
      _routePacket(ack);

    } else {
      // Forward the packet unicast or flood fallback
      _routePacket(packet);
    }
  }

  void _processAck(MeshPacket packet) async {
    if (_identity == null) return;

    if (packet.receiverId == _identity!.userId) {
      final ackedMsgId = packet.payload;
      final msg = await dbService.getMessage(ackedMsgId);
      if (msg != null) {
        msg.isDelivered = true;
        await dbService.saveMessage(msg);
        _messageController.add(msg); // Notify watchers
      }
    } else {
      _routePacket(packet);
    }
  }

  void _processTyping(MeshPacket packet) {
    // Forward typing events
    if (packet.receiverId == _identity?.userId) {
      // Notify UI
    } else {
      _routePacket(packet);
    }
  }

  // --- Core Mesh Routing Logic ---

  /// Finds or initiates route discovery for a destination peer.
  Future<List<String>> _resolveRoute(String targetUserId) async {
    // 1. Direct neighbor check
    if (_neighbors[targetUserId]?.isConnected ?? false) {
      return [_identity!.userId, targetUserId];
    }

    // 2. Cache check
    final cached = _routeCache[targetUserId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 3. Initiate AODV Route Request (RREQ)
    final completer = Completer<List<String>>();
    _rreqCompleters[targetUserId] = completer;

    final rreq = MeshPacket(
      id: const Uuid().v4(),
      senderId: _identity!.userId,
      receiverId: targetUserId,
      type: 'RREQ',
      ttl: 7,
      hopCount: 0,
      payload: '',
      signature: '',
      path: [_identity!.userId],
    );

    // Flood discovery packet
    _floodPacket(rreq);

    // Wait with timeout
    try {
      return await completer.future.timeout(const Duration(seconds: 4));
    } catch (_) {
      _rreqCompleters.remove(targetUserId);
      return []; // Return empty if route discovery timed out
    }
  }

  /// Sends a packet unicast to the next hop along the path. If no path, broadcasts to all.
  Future<bool> _routePacket(MeshPacket packet, {List<String>? path, bool useFloodFallback = true}) async {
    final routePath = path ?? _routeCache[packet.receiverId];

    if (routePath != null && routePath.isNotEmpty) {
      // Find where we are on the path
      final ownIdx = routePath.indexOf(_identity!.userId);
      if (ownIdx != -1 && ownIdx < routePath.length - 1) {
        final nextHop = routePath[ownIdx + 1];
        final nextHopNeighbor = _neighbors[nextHop];
        
        if (nextHopNeighbor != null && nextHopNeighbor.isConnected) {
          final forwardedPacket = packet.copyWith(
            ttl: packet.ttl - 1,
            hopCount: packet.hopCount + 1,
          );
          await bleService.sendData(nextHop, forwardedPacket.toBytes());
          return true;
        }
      }
    }

    // Fallback: Flood routing if unicast route failed/is missing
    if (useFloodFallback && packet.ttl > 1) {
      final forwardedPacket = packet.copyWith(
        ttl: packet.ttl - 1,
        hopCount: packet.hopCount + 1,
      );
      _floodPacket(forwardedPacket);
      return true;
    }

    return false;
  }

  /// Broadcasts a packet to all directly connected neighbors.
  void _floodPacket(MeshPacket packet) {
    _neighbors.forEach((peerId, n) {
      if (n.isConnected && peerId != packet.senderId) {
        bleService.sendData(peerId, packet.toBytes());
      }
    });
  }

  void _broadcastHeartbeat() {
    if (_identity == null || !_isPairingEnabled) return;

    final profile = {
      'userId': _identity!.userId,
      'nickname': _identity!.nickname,
    };
    final jsonStr = jsonEncode(profile);

    final packet = MeshPacket(
      id: const Uuid().v4(),
      senderId: _identity!.userId,
      receiverId: 'ALL',
      type: 'HEARTBEAT',
      ttl: 1,
      hopCount: 0,
      payload: jsonStr,
      signature: '',
      path: [_identity!.userId],
    );

    _floodPacket(packet);
  }

  void _runMaintenance() {
    // 1. Discard stale routing packet IDs from DB
    final cleanBefore = DateTime.now().subtract(const Duration(minutes: 10));
    dbService.pruneOldPackets(cleanBefore);

    // 2. Discard stale assemblers
    final cleanAssemblersBefore = DateTime.now().subtract(const Duration(minutes: 3));
    _assemblers.removeWhere((sig, assembler) => assembler.timestamp.isBefore(cleanAssemblersBefore));

    // 3. Mark offline neighbors if not seen in 20 seconds
    final now = DateTime.now();
    _neighbors.forEach((id, n) {
      if (now.difference(n.lastSeen).inSeconds > 20) {
        if (n.isConnected) {
          bleService.disconnectFrom(id);
        }
        n.isConnected = false;
      }
    });
    _neighborController.add(_neighbors.values.toList());
  }

  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _maintenanceTimer?.cancel();
    await _discoverySub?.cancel();
    await _connectionSub?.cancel();
    await _dataSub?.cancel();

    await _messageController.close();
    await _neighborController.close();
    await _routedPacketController.close();
    await _chunkProgressController.close();
  }
}
