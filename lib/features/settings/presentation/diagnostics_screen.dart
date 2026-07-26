import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../mesh/data/mesh_router.dart';
import '../../mesh/domain/mesh_packet.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final List<String> _packetLogs = [];
  List<Neighbor> _neighborsList = [];
  StreamSubscription? _packetSub;
  StreamSubscription? _neighborSub;
  StreamSubscription? _messageSub;

  @override
  void initState() {
    super.initState();
    _addLog('Diagnostics session started. Telemetry initialized.');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(meshRouterStateProvider).valueOrNull;
      final identity = ref.read(userIdentityProvider).valueOrNull;
      
      if (identity != null) {
        _addLog('Local Node ID: ${identity.userId}');
        _addLog('Local Nickname: ${identity.nickname}');
      }

      if (router != null) {
        setState(() {
          _neighborsList = router.activeNeighbors;
        });

        // Listen for routed packets
        _packetSub = router.onPacketRouted.listen((packet) {
          final senderShort = packet.senderId.substring(0, min(packet.senderId.length, 8));
          final receiverShort = packet.receiverId.substring(0, min(packet.receiverId.length, 8));
          _addLog(
            'Routed [${packet.type}] | Hop: ${packet.hopCount} | '
            'Src: $senderShort | Dest: $receiverShort | Path: ${packet.path.join(" -> ")}'
          );
        });

        // Listen for neighbor updates
        _neighborSub = router.onNeighborsUpdated.listen((neighbors) {
          if (mounted) {
            setState(() {
              _neighborsList = neighbors;
            });
            _addLog('Neighbors updated. Direct peer count: ${neighbors.where((n) => n.isConnected).length}');
          }
        });

        // Listen for new messages
        _messageSub = router.onNewMessage.listen((msg) {
          _addLog('Received encrypted message packet from: ${msg.senderId}');
        });
      } else {
        _addLog('ERROR: Mesh Router is not active or initialized.');
      }
    });
  }

  @override
  void dispose() {
    _packetSub?.cancel();
    _neighborSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      final time = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
      _packetLogs.insert(0, '[$time] $message');
      if (_packetLogs.length > 250) {
        _packetLogs.removeLast();
      }
    });
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -65) return Colors.green;
    if (rssi >= -85) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final router = ref.watch(meshRouterStateProvider).valueOrNull;
    final routes = router?.routeCache ?? {};

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mesh Diagnostics'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bluetooth), text: 'Neighbors'),
              Tab(icon: Icon(Icons.alt_route), text: 'Routes'),
              Tab(icon: Icon(Icons.terminal), text: 'Logs'),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.chatBackgroundDark : Colors.grey[50],
          ),
          child: TabBarView(
            children: [
              // Neighbors Tab
              _buildNeighborsTab(theme),

              // Routes Tab
              _buildRoutesTab(theme, routes),

              // Logs Tab
              _buildLogsTab(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeighborsTab(ThemeData theme) {
    final connectedNeighbors = _neighborsList.where((n) => n.isConnected).toList();
    final scannedNeighbors = _neighborsList.where((n) => !n.isConnected).toList();

    if (_neighborsList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Scanning for BLE mesh nodes...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (connectedNeighbors.isNotEmpty) ...[
          Text(
            'ACTIVE CONNECTIONS (${connectedNeighbors.length})',
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...connectedNeighbors.map((n) => _buildNeighborCard(theme, n, true)),
          const SizedBox(height: 24),
        ],
        if (scannedNeighbors.isNotEmpty) ...[
          Text(
            'DISCOVERED ADVERTISING NODES (${scannedNeighbors.length})',
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...scannedNeighbors.map((n) => _buildNeighborCard(theme, n, false)),
        ],
      ],
    );
  }

  Widget _buildNeighborCard(ThemeData theme, Neighbor neighbor, bool isConnected) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isConnected ? theme.colorScheme.primary : Colors.grey).withOpacity(0.1),
          child: Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
            color: isConnected ? theme.colorScheme.primary : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Text(neighbor.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (neighbor.cryptoUserId != null)
              Icon(Icons.verified, size: 16, color: theme.colorScheme.primary),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'MAC: ${neighbor.userId}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            if (neighbor.cryptoUserId != null)
              Text(
                'CryptoID: ${neighbor.cryptoUserId!.substring(0, min(neighbor.cryptoUserId!.length, 12))}...',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _getRssiColor(neighbor.rssi).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${neighbor.rssi} dBm',
            style: TextStyle(
              color: _getRssiColor(neighbor.rssi),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutesTab(ThemeData theme, Map<String, List<String>> routes) {
    if (routes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alt_route, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No mesh routes resolved yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                'Routes are dynamically cached here once multi-hop messaging takes place.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'ROUTING CACHE PATHS (${routes.length})',
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...routes.entries.map((entry) {
          final target = entry.key;
          final path = entry.value;
          final hopCount = path.length - 1;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target Peer: ${target.substring(0, min(target.length, 12))}...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Chip(
                        label: Text('$hopCount ${hopCount == 1 ? "Hop" : "Hops"}'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Resolved Hop Path:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: path.asMap().entries.map((pEntry) {
                      final idx = pEntry.key;
                      final node = pEntry.value;
                      final isLast = idx == path.length - 1;
                      final nodeShort = node.substring(0, min(node.length, 6));

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLast ? theme.colorScheme.primary : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              idx == 0 ? 'Me' : nodeShort,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isLast ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (!isLast)
                            const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                        ],
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLogsTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls Row
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.scaffoldBackgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                  SizedBox(width: 8),
                  Text('Live Feed Console', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy all logs',
                    onPressed: () {
                      if (_packetLogs.isEmpty) return;
                      Clipboard.setData(ClipboardData(text: _packetLogs.reversed.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logs copied to clipboard!')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'Clear logs',
                    onPressed: () {
                      setState(() {
                        _packetLogs.clear();
                        _addLog('Logs cleared.');
                      });
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        
        // Logs Terminal
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[900]!),
            ),
            child: _packetLogs.isEmpty
              ? const Center(child: Text('[Empty Console]', style: TextStyle(color: Colors.grey, fontFamily: 'monospace')))
              : ListView.builder(
                  reverse: false,
                  itemCount: _packetLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        _packetLogs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                ),
          ),
        )
      ],
    );
  }
}
