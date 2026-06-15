import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_status.dart';
import '../services/audio_queue_manager.dart';
import '../services/controller_session.dart';
import '../services/websocket_service.dart';
import '../services/webrtc_service.dart';

final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final audioQueueProvider = Provider<AudioQueueManager>((ref) {
  final manager = AudioQueueManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final controllerIpProvider = StateProvider<String>((ref) => '192.168.1.39');
final controllerPortProvider = StateProvider<int>((ref) => 8080);
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
  final ip = ref.watch(controllerIpProvider);
  final port = ref.watch(controllerPortProvider);
  final session = ControllerSession(
    webSocket: ref.watch(websocketServiceProvider),
    webRTC: ref.watch(webrtcServiceProvider),
    audioQueue: ref.watch(audioQueueProvider),
    controllerHttpBase: 'http://$ip:$port',
    onStatusChanged: (status) {
      ref.read(connectionStatusProvider.notifier).state = status;
    },
  );
  Future.microtask(() {
    session.start();
  });
  ref.onDispose(session.dispose);
  return session;
});
