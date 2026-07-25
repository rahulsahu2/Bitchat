import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/ble/mock_ble_service.dart';
import '../../mesh/domain/mesh_packet.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  final List<TravelingPacket> _travelingPackets = [];
  StreamSubscription? _packetSubscription;

  // Configuration for simulator controls
  double _aliceX = 10;
  double _bobX = 80;
  double _charlieX = 180;
  bool _automatedTraffic = false;
  Timer? _trafficTimer;

  @override
  void initState() {
    super.initState();
    // Repaint canvas at 60fps for smooth packet travel animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Listen to routed packets stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(meshRouterStateProvider).valueOrNull;
      if (router != null) {
        _packetSubscription = router.onPacketRouted.listen(_handlePacketRouted);
      }
      
      // Load initial coordinates if nodes exist
      final medium = MockBleMedium.instance;
      setState(() {
        _aliceX = medium.nodes['alice-id']?.position.x ?? 10;
        _bobX = medium.nodes['bob-id']?.position.x ?? 80;
        _charlieX = medium.nodes['charlie-id']?.position.x ?? 180;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _packetSubscription?.cancel();
    _trafficTimer?.cancel();
    super.dispose();
  }

  void _handlePacketRouted(MeshPacket packet) {
    // Animate the hop!
    // For simplicity, if it's a broadcast or flooded packet, we animate from sender to all its connected nodes.
    // If it's a unicast routed packet, we animate from sender to its next hop receiver.
    if (!mounted) return;

    final medium = MockBleMedium.instance;
    final sender = medium.nodes[packet.senderId];
    if (sender == null) return;

    if (packet.receiverId == 'ALL' || packet.type == 'RREQ') {
      // Broadcast/flood: animate to all connected neighbors
      for (final peerId in sender.connectedPeers) {
        setState(() {
          _travelingPackets.add(
            TravelingPacket(
              id: packet.id,
              fromId: packet.senderId,
              toId: peerId,
              color: packet.type == 'RREQ' ? Colors.orange : Colors.blue,
              startTime: DateTime.now(),
            ),
          );
        });
      }
    } else {
      // Unicast: animate to the next hop target.
      // Since it's traveling, we locate the next peer in range that is connected
      for (final peerId in sender.connectedPeers) {
        final peer = medium.nodes[peerId];
        if (peer != null && peer.connectedPeers.contains(packet.senderId)) {
          // Add animation
          setState(() {
            _travelingPackets.add(
              TravelingPacket(
                id: packet.id,
                fromId: packet.senderId,
                toId: peerId,
                color: packet.type == 'ACK' ? Colors.green : Colors.purple,
                startTime: DateTime.now(),
              ),
            );
          });
        }
      }
    }
  }

  void _injectVirtualNodes() {
    final medium = MockBleMedium.instance;
    medium.registerNode('alice-id', 'Alice', x: _aliceX, y: 100);
    medium.registerNode('bob-id', 'Bob', x: _bobX, y: 100);
    medium.registerNode('charlie-id', 'Charlie', x: _charlieX, y: 100);
    
    // Trigger scanning update in medium
    medium.triggerScanUpdate();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Virtual Nodes Alice, Bob, and Charlie successfully registered!')),
    );
  }

  void _updateNodePosition(String id, double x) {
    final medium = MockBleMedium.instance;
    medium.updateNodePosition(id, x, 100);
    medium.triggerScanUpdate();
  }

  void _toggleAutomatedTraffic(bool value) {
    setState(() {
      _automatedTraffic = value;
    });

    if (value) {
      _trafficTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        final router = ref.read(meshRouterStateProvider).valueOrNull;
        if (router != null && router.identity?.userId == 'alice-id') {
          // Alice sends a diagnostics ping to Charlie
          await router.sendMessage('charlie-id', 'Auto Mesh Ping #${Random().nextInt(100)}');
        }
      });
    } else {
      _trafficTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Clean up expired packet animations
    final now = DateTime.now();
    _travelingPackets.removeWhere(
      (p) => now.difference(p.startTime) >= p.duration,
    );

    // Read node entries from simulator medium
    final mediumNodes = MockBleMedium.instance.nodes.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Topology & Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              MockBleMedium.instance.triggerScanUpdate();
              setState(() {});
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Visual Canvas Graph Panel
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.chatBackgroundDark : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: MeshGraphPainter(
                        nodes: mediumNodes,
                        travelingPackets: _travelingPackets,
                        theme: theme,
                      ),
                      child: Container(),
                    );
                  },
                ),
              ),
            ),
          ),

          // Controls Panel
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Simulation Console',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.group_add),
                        label: const Text('Inject Nodes'),
                        onPressed: _injectVirtualNodes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Drag sliders to move nodes and change RSSI in real-time. Link breaks if distance exceeds 120.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  // Alice Position
                  Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Alice X')),
                      Expanded(
                        child: Slider(
                          value: _aliceX,
                          min: 0,
                          max: 200,
                          divisions: 20,
                          label: _aliceX.round().toString(),
                          onChanged: (val) {
                            setState(() => _aliceX = val);
                            _updateNodePosition('alice-id', val);
                          },
                        ),
                      ),
                    ],
                  ),

                  // Bob Position
                  Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Bob X')),
                      Expanded(
                        child: Slider(
                          value: _bobX,
                          min: 0,
                          max: 200,
                          divisions: 20,
                          label: _bobX.round().toString(),
                          onChanged: (val) {
                            setState(() => _bobX = val);
                            _updateNodePosition('bob-id', val);
                          },
                        ),
                      ),
                    ],
                  ),

                  // Charlie Position
                  Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Charlie X')),
                      Expanded(
                        child: Slider(
                          value: _charlieX,
                          min: 0,
                          max: 200,
                          divisions: 20,
                          label: _charlieX.round().toString(),
                          onChanged: (val) {
                            setState(() => _charlieX = val);
                            _updateNodePosition('charlie-id', val);
                          },
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 32),
                  
                  // Auto traffic
                  SwitchListTile(
                    title: const Text('Generate Automated Ping Traffic'),
                    subtitle: const Text('Simulates periodic multi-hop messaging loops'),
                    value: _automatedTraffic,
                    onChanged: _toggleAutomatedTraffic,
                  ),
                  const SizedBox(height: 8),

                  // Map Legend Card
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Legend / Packet Color Code:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildLegendBadge(Colors.orange, 'RREQ (Route Search)'),
                              const SizedBox(width: 12),
                              _buildLegendBadge(Colors.purple, 'MSG (Encrypted Text)'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildLegendBadge(Colors.green, 'ACK (Delivery Acknowledged)'),
                              const SizedBox(width: 12),
                              _buildLegendBadge(Colors.blue, 'Heartbeat (Scan discovery)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegendBadge(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class TravelingPacket {
  final String id;
  final String fromId;
  final String toId;
  final Color color;
  final DateTime startTime;
  final Duration duration;

  TravelingPacket({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.color,
    required this.startTime,
    this.duration = const Duration(milliseconds: 1200),
  });
}

class MeshGraphPainter extends CustomPainter {
  final List<SimulatedNodeRegistryEntry> nodes;
  final List<TravelingPacket> travelingPackets;
  final ThemeData theme;

  MeshGraphPainter({
    required this.nodes,
    required this.travelingPackets,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = theme.brightness == Brightness.dark;
    
    // Scale coordinates from mock BLE positions (typically x ranges 0..200, y is 100)
    // to fit the actual canvas coordinates.
    // Node map range: X=0..200 -> margins: X = 40 .. size.width - 40
    // Node Y=100 -> center: Y = size.height / 2
    Offset getNodeCoords(SimulatedNodeRegistryEntry node) {
      final double percentX = (node.position.x).clamp(0.0, 200.0) / 200.0;
      final double x = 40.0 + percentX * (size.width - 80.0);
      final double y = size.height / 2; // Linear row layout
      return Offset(x, y);
    }

    // 1. Draw Connection Links
    final Paint linePaint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final Set<String> drawnLinks = {};

    for (final node in nodes) {
      final nodeCoords = getNodeCoords(node);
      for (final peerId in node.connectedPeers) {
        final peer = nodes.firstWhere((n) => n.userId == peerId, orElse: () => node);
        if (peer == node) continue; // Peer not found or self
        
        final linkKey = node.userId.compareTo(peerId) < 0 
            ? '${node.userId}-$peerId' 
            : '$peerId-${node.userId}';

        if (drawnLinks.contains(linkKey)) continue;
        drawnLinks.add(linkKey);

        final peerCoords = getNodeCoords(peer);

        // Calculate link distance to determine connection quality (RSSI)
        final distance = (node.position.x - peer.position.x).abs();
        
        // Link color scales from green to red based on distance
        if (distance <= 60) {
          linePaint.color = Colors.green.withOpacity(0.4);
        } else if (distance <= 100) {
          linePaint.color = Colors.orange.withOpacity(0.4);
        } else {
          linePaint.color = Colors.red.withOpacity(0.3);
        }

        canvas.drawLine(nodeCoords, peerCoords, linePaint);
      }
    }

    // 2. Draw Traveling Packet Dots
    final Paint packetPaint = Paint()..style = PaintingStyle.fill;

    for (final packet in travelingPackets) {
      final fromNode = nodes.firstWhere((n) => n.userId == packet.fromId, orElse: () => nodes.first);
      final toNode = nodes.firstWhere((n) => n.userId == packet.toId, orElse: () => nodes.first);
      
      final fromCoords = getNodeCoords(fromNode);
      final toCoords = getNodeCoords(toNode);

      final elapsed = DateTime.now().difference(packet.startTime).inMilliseconds;
      final double progress = (elapsed / packet.duration.inMilliseconds).clamp(0.0, 1.0);

      // Lerp coordinates
      final Offset currentCoords = Offset(
        fromCoords.dx + (toCoords.dx - fromCoords.dx) * progress,
        fromCoords.dy + (toCoords.dy - fromCoords.dy) * progress,
      );

      // Draw packet outer glow
      packetPaint.color = packet.color.withOpacity(0.3);
      canvas.drawCircle(currentCoords, 9.0, packetPaint);

      // Draw packet inner core
      packetPaint.color = packet.color;
      canvas.drawCircle(currentCoords, 5.0, packetPaint);
    }

    // 3. Draw Nodes (Devices)
    final Paint circlePaint = Paint()..style = PaintingStyle.fill;
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final node in nodes) {
      final coords = getNodeCoords(node);
      final isLocal = node.userId == 'alice-id'; // Assume Alice is the primary simulator user

      // Node base circle
      circlePaint.color = isLocal 
          ? theme.colorScheme.primary 
          : (isDark ? Colors.grey[800]! : Colors.white);
      canvas.drawCircle(coords, 22.0, circlePaint);

      // Node border
      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = isLocal ? Colors.green : Colors.grey;
      canvas.drawCircle(coords, 22.0, borderPaint);

      // Draw letter index inside circle
      final initial = node.nickname.isNotEmpty ? node.nickname[0].toUpperCase() : '?';
      textPainter.text = TextSpan(
        text: initial,
        style: TextStyle(
          color: isLocal ? Colors.white : (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(coords.dx - textPainter.width / 2, coords.dy - textPainter.height / 2),
      );

      // Draw device nickname below circle
      textPainter.text = TextSpan(
        text: '${node.nickname}${isLocal ? ' (Local)' : ''}',
        style: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[800],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(coords.dx - textPainter.width / 2, coords.dy + 28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
