import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/sign_translation.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/live_camera_preview.dart';

class SignLanguageScreen extends ConsumerWidget {
  const SignLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String>(activeModeProvider, (previous, next) {
      if (next == 'danger') {
        if (context.mounted) {
          context.go('/');
        }
      }
    });

    final history = [
      SignTranslation(
        text: 'I need help',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      SignTranslation(
        text: 'Thank you',
        timestamp: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Language')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/emergency'),
        icon: const Icon(Icons.warning),
        label: const Text('SOS'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Camera translation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const LiveCameraPreview(),
                    const SizedBox(height: 16),
                    const Text(
                      'Current text',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'I need help',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Speak translation'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Conversation history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    return GlassCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(0),
                        title: Text(
                          entry.text,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
