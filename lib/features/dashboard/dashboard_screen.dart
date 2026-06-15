import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connection_status.dart';
import '../../models/alert_event.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/status_chip.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final wsUrl = ref.watch(websocketUrlProvider);
    String controllerIpValue = 'Unknown';
    try {
      final uri = Uri.parse(wsUrl);
      controllerIpValue = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    } catch (_) {
      controllerIpValue = wsUrl;
    }
    final statusLabel = connectionStatus == ConnectionStatus.connected
        ? 'Connected'
        : connectionStatus == ConnectionStatus.connecting
        ? 'Connecting'
        : connectionStatus == ConnectionStatus.reconnecting
        ? 'Reconnecting'
        : 'Disconnected';

    final events = [
      AlertEvent(
        message: 'Vehicle detected',
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        category: 'danger',
      ),
      AlertEvent(
        message: 'John recognized',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        category: 'face',
      ),
      AlertEvent(
        message: 'Sign translated: "Need help"',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        category: 'sign',
      ),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/emergency'),
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text('SOS'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sentinel Companion',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      StatusChip(
                        label: statusLabel,
                        color: connectionStatus == ConnectionStatus.connected
                            ? Colors.greenAccent
                            : Colors.amberAccent,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings, color: Colors.white70),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Controller Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DashboardInfoTile(
                          title: 'Controller IP',
                          value: controllerIpValue,
                        ),
                        _DashboardInfoTile(title: 'WebRTC', value: 'Active'),
                        _DashboardInfoTile(title: 'Battery', value: '94%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String?>(
                      future: NetworkInfo().getWifiIP(),
                      builder: (context, snapshot) {
                        final deviceIp =
                            snapshot.connectionState == ConnectionState.done
                            ? (snapshot.data ?? 'Unknown')
                            : '...';
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'This device IP',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white54),
                            ),
                            Text(
                              deviceIp,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 1,
                  childAspectRatio: 3,
                  mainAxisSpacing: 16,
                  children: [
                    _ModeCard(
                      icon: Icons.shield,
                      title: 'Danger Detection',
                      subtitle: 'Monitor nearby hazards in real time',
                      color: Colors.redAccent,
                      route: '/danger',
                      mode: 'danger',
                    ),
                    _ModeCard(
                      icon: Icons.face_retouching_natural,
                      title: 'Face Recognition',
                      subtitle: 'Identify known people quickly',
                      color: Colors.blueAccent,
                      route: '/face',
                      mode: 'face',
                    ),
                    _ModeCard(
                      icon: Icons.sign_language,
                      title: 'Sign Language',
                      subtitle: 'Translate gestures to text and speech',
                      color: Colors.greenAccent,
                      route: '/sign',
                      mode: 'sign',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recent events',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: events
                      .map(
                        (event) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                event.message,
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardInfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _DashboardInfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ModeCard extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final String mode;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final session = ref.read(controllerSessionProvider);
              session.webSocket.send({
                'type': 'set_mode',
                'mode': mode,
              });
              context.push(route);
            },
            child: const Text('Enter'),
          ),
        ],
      ),
    );
  }
}
