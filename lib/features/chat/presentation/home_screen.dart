import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/providers.dart';
import 'chat_screen.dart';
import 'widgets/chat_bubble.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/presentation/qr_pairing_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BitChat Mesh',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QrPairingScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3.0,
          labelColor: isDark ? theme.colorScheme.secondary : Colors.white,
          unselectedLabelColor: isDark ? Colors.grey : const Color(0xB3FFFFFF),
          indicatorColor: isDark ? theme.colorScheme.secondary : Colors.white,
          tabs: const [
            Tab(text: 'CHATS', icon: Icon(Icons.chat_bubble)),
            Tab(text: 'NEARBY', icon: Icon(Icons.radar)),
            Tab(text: 'SETTINGS', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsTab(context),
          _buildNearbyTab(context),
          const SettingsScreen(),
        ],
      ),
    );
  }

  Widget _buildChatsTab(BuildContext context) {
    final chatsAsync = ref.watch(chatsStreamProvider);
    final theme = Theme.of(context);

    return chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.chat_bubble_outline, size: 80, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Chats',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ensure Bluetooth is turned on, navigate to the NEARBY tab, and connect to nearby nodes to chat completely offline!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Search Nearby Neighbors'),
                    onPressed: () => _tabController.animateTo(1),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final Color avatarColor = Color(chat.chatId.hashCode | 0xFF000000);

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor.withOpacity(0.2),
                child: Text(
                  chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                  style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              title: Text(
                chat.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                chat.lastMessageText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(chat.lastMessageTime),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (chat.unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        chat.unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      peerId: chat.chatId,
                      nickname: chat.name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading chats: $err')),
    );
  }

  Widget _buildNearbyTab(BuildContext context) {
    final neighborsAsync = ref.watch(activeNeighborsProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Radar / scanning indicator
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          width: double.infinity,
          color: theme.colorScheme.primary.withOpacity(0.05),
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              Text(
                'Scanning for nearby BLE mesh nodes...',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // List of discovered devices
        Expanded(
          child: neighborsAsync.when(
            data: (neighbors) {
              if (neighbors.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No devices found yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ensure other devices have Bluetooth enabled and are running BitChat Mesh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: neighbors.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final neighbor = neighbors[index];
                  final isConnected = neighbor.isConnected;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.bluetooth, color: theme.colorScheme.primary),
                    ),
                    title: Row(
                      children: [
                        Text(
                          neighbor.nickname,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        if (isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Connected',
                              style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text('Signal: ${neighbor.rssi} dBm (RSSI)'),
                    trailing: isConnected
                        ? TextButton.icon(
                            icon: const Icon(Icons.chat),
                            label: const Text('Chat'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    peerId: neighbor.userId,
                                    nickname: neighbor.nickname,
                                  ),
                                ),
                              );
                            },
                          )
                        : OutlinedButton(
                            child: const Text('Connect'),
                            onPressed: () async {
                              final ble = ref.read(bleServiceProvider);
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Connecting to ${neighbor.nickname}...')),
                                );
                                await ble.connectTo(neighbor.userId);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to connect: $e')),
                                  );
                                }
                              }
                            },
                          ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading neighbors: $err')),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('jm').format(time);
  }
}
