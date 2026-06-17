import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tts_service.dart';
import '../services/sign_language_tts_service.dart';
import '../models/connection_status.dart';
import '../services/audio_queue_manager.dart';
import '../services/controller_session.dart';
import '../services/websocket_service.dart';
import '../services/webrtc_service.dart';

import 'active_mode_provider.dart';
export 'active_mode_provider.dart';

final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final audioQueueProvider = Provider<AudioQueueManager>((ref) {
  final manager = AudioQueueManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final ttsProvider = Provider<TtsService>((ref) {
  final tts = TtsService();

  tts.init();

  return tts;
});

/// Hazard-state values that indicate an active alert / danger condition.
/// When any of these are reported, sign-language TTS must stop immediately.
const _alertHazardStates = {'alert', 'danger'};

final signLanguageTtsProvider = Provider<SignLanguageTtsService>((ref) {
  final service = SignLanguageTtsService();
  service.init();

  // Listen to hazard state changes and stop TTS on any alert/danger.
  ref.listen<String>(hazardStateProvider, (previous, next) {
    final normalised = next.toLowerCase();
    if (_alertHazardStates.any((s) => normalised.contains(s))) {
      service.stop();
    }
  });

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final controllerIpProvider = StateProvider<String>((ref) => '192.168.1.8');
final controllerPortProvider = StateProvider<int>((ref) => 8765);
final webrtcStunServerProvider = StateProvider<String>(
  (ref) => 'stun:stun.l.google.com:19302',
);

final websocketUrlProvider = Provider<String>((ref) {
  final ip = ref.watch(controllerIpProvider);
  final port = ref.watch(controllerPortProvider);
  return 'ws://$ip:$port';
});

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final url = ref.watch(websocketUrlProvider);
  final service = WebSocketService(url: url);
  ref.onDispose(service.dispose);
  return service;
});

final connectionStatusProvider = StateProvider<ConnectionStatus>(
  (ref) => ConnectionStatus.disconnected,
);

/// Hazard state reported by the backend (e.g. "Alert", "Idle").
final hazardStateProvider = StateProvider<String>((ref) => 'Idle');

/// Frame age reported by the backend.
final frameAgeProvider = StateProvider<String>((ref) => '—');
final signTranslationProvider = StateProvider<String>((ref) => '');
final webrtcServiceProvider = Provider<WebRTCService>((ref) {
  final service = WebRTCService(
    stunServer: ref.watch(webrtcStunServerProvider),
  );
  ref.onDispose(() async {
    await service.dispose();
  });
  return service;
});

final controllerSessionProvider = Provider<ControllerSession>((ref) {
  // Clear sign translation when active mode changes
  ref.listen<String>(activeModeProvider, (previous, next) {
    ref.read(signTranslationProvider.notifier).state = '';
  });
  final ip = ref.watch(controllerIpProvider);
  final port = ref.watch(controllerPortProvider);
  final session = ControllerSession(
    webSocket: ref.watch(websocketServiceProvider),
    webRTC: ref.watch(webrtcServiceProvider),
    audioQueue: ref.watch(audioQueueProvider),
    controllerHttpBase: 'http://$ip:$port',
    // Provide a live read of the active mode so ControllerSession can
    // check it at alert-arrival time without holding a Riverpod ref.
    getActiveMode: () => ref.read(activeModeProvider),
    onStatusChanged: (status) {
      ref.read(connectionStatusProvider.notifier).state = status;
    },
    onHazardStateChanged: (state) {
      ref.read(hazardStateProvider.notifier).state = state;
    },
    onModeOverride: (mode) {
      ref.read(activeModeProvider.notifier).state = mode;
      ref.read(websocketServiceProvider).send({
        'type': 'set_mode',
        'mode': mode,
      });
    },
    onFrameAgeChanged: (age) {
      ref.read(frameAgeProvider.notifier).state = age;
    },

    onSignTranslation: (text) {
      ref.read(signTranslationProvider.notifier).state = text;
    },
  );
  Future.microtask(() {
    session.start();
  });
  ref.onDispose(session.dispose);
  return session;
});
