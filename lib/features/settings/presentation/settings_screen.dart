import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';
import 'qr_pairing_screen.dart';
import 'diagnostics_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nicknameController = TextEditingController();
  final _statusController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final identity = ref.read(userIdentityProvider).valueOrNull;
      if (identity != null) {
        _nicknameController.text = identity.nickname;
        _statusController.text = identity.status;
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    final status = _statusController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nickname cannot be empty')),
      );
      return;
    }

    final identity = ref.read(userIdentityProvider).valueOrNull;
    if (identity != null) {
      await ref.read(userIdentityProvider.notifier).updateProfile(
            nickname,
            status,
            identity.avatarColor,
          );
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identityAsync = ref.watch(userIdentityProvider);
    final isSimMode = ref.watch(simulationModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveProfile,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
        ],
      ),
      body: identityAsync.when(
        data: (identity) {
          if (identity == null) {
            return const Center(child: Text('No identity profiles loaded.'));
          }

          final Color avatarColor = Color(identity.avatarColor);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Header profile card
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: avatarColor,
                        child: Text(
                          identity.nickname.isNotEmpty ? identity.nickname[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name & Status inputs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nicknameController,
                            enabled: _isEditing,
                            decoration: const InputDecoration(
                              labelText: 'Nickname',
                              prefixIcon: Icon(Icons.person),
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _statusController,
                            enabled: _isEditing,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              prefixIcon: Icon(Icons.info_outline),
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cryptographic key details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: const Icon(Icons.key),
                      title: const Text('Cryptographic Key Information'),
                      subtitle: const Text('Curve NIST P-256 Public Key Fingerprint'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  identity.publicKey,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy Public Key'),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: identity.publicKey));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Public Key copied to clipboard!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Settings List Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    'DEVELOPER OPTIONS',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                
                // Simulation toggle
                SwitchListTile(
                  secondary: Icon(isSimMode ? Icons.layers : Icons.bluetooth),
                  title: const Text('BLE Simulation Mode'),
                  subtitle: Text(
                    isSimMode 
                        ? 'Simulating Bluetooth mesh network in-memory.' 
                        : 'Using actual hardware BLE drivers.'
                  ),
                  value: isSimMode,
                  onChanged: (val) {
                    ref.read(simulationModeProvider.notifier).state = val;
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.animation),
                  title: const Text('Simulation Canvas Graph'),
                  subtitle: const Text('View and position virtual nodes, watch packet travel.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DiagnosticsScreen()),
                    );
                  },
                ),

                const Divider(height: 32),

                // Pairing Shortcut
                ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: const Text('QR Pairing & Trust Handshake'),
                  subtitle: const Text('Scan or show QR to verify keys offline.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const QrPairingScreen()),
                    );
                  },
                ),
                const SizedBox(height: 48),
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
