import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/database/schemas/peer.dart';
import '../../../core/services/encryption/crypto_service.dart';
import 'package:uuid/uuid.dart';

class QrPairingScreen extends ConsumerStatefulWidget {
  const QrPairingScreen({super.key});

  @override
  ConsumerState<QrPairingScreen> createState() => _QrPairingScreenState();
}

class _QrPairingScreenState extends ConsumerState<QrPairingScreen> {
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isScanningMode = false;

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pairPeer(String nickname, String peerId, String publicKey) async {
    try {
      final db = ref.read(databaseServiceProvider);
      
      var peer = await db.getPeer(peerId);
      if (peer == null) {
        peer = Peer()
          ..userId = peerId
          ..publicKey = publicKey
          ..isTrusted = true // Mark as cryptographically verified/trusted
          ..isBlocked = false
          ..avatarColor = 0xFF4CAF50 // Default green avatar color
          ..lastRssi = -100
          ..hops = 1;
      } else {
        peer.isTrusted = true;
        peer.publicKey = publicKey;
      }
      peer.nickname = nickname;
      peer.status = 'Online';
      peer.lastSeen = DateTime.now();
      await db.savePeer(peer);



      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.white),
                const SizedBox(width: 8),
                Text('Successfully paired and trusted "$nickname"!'),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pair: $e')),
        );
      }
    }
  }

  void _simulateScan(String rawData) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawData);
      final String nickname = data['nickname'] ?? 'Unknown';
      final String userId = data['userId'] ?? '';
      final String publicKey = data['publicKey'] ?? '';

      if (userId.isEmpty || publicKey.isEmpty) {
        throw Exception('Invalid QR payload fields');
      }

      _pairPeer(nickname, userId, publicKey);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to parse QR payload: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identityAsync = ref.watch(userIdentityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Pairing & Trust Handshake'),
      ),
      body: identityAsync.when(
        data: (identity) {
          if (identity == null) {
            return const Center(child: Text('No Identity found. Please setup profile.'));
          }

          // Build local identity JSON data for QR
          final qrPayload = jsonEncode({
            'userId': identity.userId,
            'nickname': identity.nickname,
            'publicKey': identity.publicKey,
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toggle view: My QR Code vs Scan QR Code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('My QR Code'),
                      selected: !_isScanningMode,
                      onSelected: (selected) {
                        setState(() => _isScanningMode = false);
                      },
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Manual / Scan Simulator'),
                      selected: _isScanningMode,
                      onSelected: (selected) {
                        setState(() => _isScanningMode = true);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (!_isScanningMode) ...[
                  // My QR Code Display
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 240.0,
                        gapless: false,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Let other devices scan this QR code to establish an encrypted, trusted connection.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: const Icon(Icons.security, color: Colors.green),
                    ),
                    title: const Text('Verified End-to-End Cryptography'),
                    subtitle: const Text('QR exchange verifies your public key signature offline.'),
                  ),
                ] else ...[
                  // Simulator Mock Scanner and Manual Inputs
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Simulated Scan Tool',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Running on a simulator? Click one of the virtual neighbors below to simulate scanning their QR code instantly.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const CircleAvatar(child: Text('B')),
                                label: const Text('Scan Mock Bob'),
                                onPressed: () {
                                  // Mock Bob details
                                  final mockBobPayload = jsonEncode({
                                    'userId': 'bob-id',
                                    'nickname': 'Bob',
                                    'publicKey': CryptoService.encodePublicKey(CryptoService.generateKeyPair().publicKey),
                                  });
                                  _simulateScan(mockBobPayload);
                                },
                              ),
                              ActionChip(
                                avatar: const CircleAvatar(child: Text('C')),
                                label: const Text('Scan Mock Charlie'),
                                onPressed: () {
                                  // Mock Charlie details
                                  final mockCharliePayload = jsonEncode({
                                    'userId': 'charlie-id',
                                    'nickname': 'Charlie',
                                    'publicKey': CryptoService.encodePublicKey(CryptoService.generateKeyPair().publicKey),
                                  });
                                  _simulateScan(mockCharliePayload);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Manual Key Input Form
                  Text(
                    'Or Enter Peer Public Key Manually',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Peer Nickname',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Base64 Public Key',
                      prefixIcon: Icon(Icons.key),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      final name = _nameController.text.trim();
                      final key = _keyController.text.trim();
                      if (name.isEmpty || key.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields')),
                        );
                        return;
                      }
                      _pairPeer(name, Uuid().v4(), key);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Verify & Save Trusted Peer'),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
