import 'dart:convert';
import 'dart:typed_data';

/// Represents a packet transmitted over the Bluetooth Mesh Network.
class MeshPacket {
  final String id;
  final String senderId;
  final String receiverId; // Can be a peer UUID or 'ALL' for broadcast/group
  final String type; // 'HEARTBEAT', 'RREQ', 'RREP', 'MSG', 'ACK', 'TYPING'
  final int ttl;
  final int hopCount;
  final String payload; // Encrypted and Base64 encoded payload
  final String signature; // Base64 signature of the payload (E2EE integrity)
  final int chunkIndex; // 0-indexed chunk number (0 for non-fragmented)
  final int totalChunks; // 1 for non-fragmented
  final List<String> path; // Accumulative node paths traversed (for route discovery)

  MeshPacket({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.ttl,
    required this.hopCount,
    required this.payload,
    required this.signature,
    this.chunkIndex = 0,
    this.totalChunks = 1,
    required this.path,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'type': type,
      'ttl': ttl,
      'hopCount': hopCount,
      'payload': payload,
      'signature': signature,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
      'path': path,
    };
  }

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      type: json['type'] as String,
      ttl: json['ttl'] as int,
      hopCount: json['hopCount'] as int,
      payload: json['payload'] as String,
      signature: json['signature'] as String,
      chunkIndex: json['chunkIndex'] as int? ?? 0,
      totalChunks: json['totalChunks'] as int? ?? 1,
      path: List<String>.from(json['path'] as List? ?? []),
    );
  }

  Uint8List toBytes() {
    final str = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(str));
  }

  factory MeshPacket.fromBytes(Uint8List bytes) {
    final str = utf8.decode(bytes);
    final json = jsonDecode(str) as Map<String, dynamic>;
    return MeshPacket.fromJson(json);
  }

  MeshPacket copyWith({
    int? ttl,
    int? hopCount,
    List<String>? path,
  }) {
    return MeshPacket(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      type: type,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      payload: payload,
      signature: signature,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      path: path ?? this.path,
    );
  }
}
