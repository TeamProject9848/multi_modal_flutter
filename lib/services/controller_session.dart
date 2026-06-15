import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/connection_status.dart';
import 'audio_queue_manager.dart';
import 'websocket_service.dart';
import 'webrtc_service.dart';

class ControllerSession {
  ControllerSession({
    required this.webSocket,
    required this.webRTC,
    required this.audioQueue,
    required this.controllerHttpBase,
    required this.onStatusChanged,
    this.onHazardStateChanged,
    this.onModeOverride,
    this.onFrameAgeChanged,
  });

  final WebSocketService webSocket;
  final WebRTCService webRTC;
  final AudioQueueManager audioQueue;
  final String controllerHttpBase;
  final ValueChanged<ConnectionStatus> onStatusChanged;

  /// Called when the backend reports a hazard-state change (e.g. "Alert", "Idle").
  final ValueChanged<String>? onHazardStateChanged;

  /// Called when the backend forces a mode switch (e.g. danger override).
  final ValueChanged<String>? onModeOverride;

  /// Called when the backend reports a new frame age value.
  final ValueChanged<String>? onFrameAgeChanged;

  StreamSubscription<Map<String, dynamic>>? _messages;
  bool _signaling = false;

  Future<void> start() async {
    _messages = webSocket.messages.listen(_handleMessage);
    webSocket.connectionStatus.addListener(_handleStatus);
    _handleStatus();
    await webSocket.connect();
  }

  void _handleStatus() {
    final status = webSocket.connectionStatus.value;
    onStatusChanged(status);
    if (status == ConnectionStatus.connected) {
      _startVideo();
    }
  }

  Future<void> _startVideo() async {
    if (_signaling) return;
    _signaling = true;
    try {
      await webRTC.initialize();
      final offer = await webRTC.createOffer();
      webSocket.send({
        'type': 'webrtc_offer',
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
    } catch (error) {
      debugPrint('Unable to start camera stream: $error');
    } finally {
      _signaling = false;
    }
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    debugPrint('WS MESSAGE: $message');

    // ── Extract state & frame_age from ANY message ──────────────
    // The backend may embed these fields in various message types,
    // not just a dedicated "state" message.
    final msgState = message['state'];
    if (msgState is String && msgState.isNotEmpty) {
      onHazardStateChanged?.call(msgState);
    }
    final frameAge = message['frame_age'];
    if (frameAge != null) {
      onFrameAgeChanged?.call(frameAge.toString());
    }

    // ── Type-specific handling ───────────────────────────────────
    switch (message['type']) {
  case 'webrtc_answer':
    final sdp = message['sdp'];
    if (sdp is String) {
      await webRTC.acceptAnswer(
        sdp: sdp,
        type: message['sdpType'] as String? ?? 'answer',
      );
    }
    break;

  case 'alert':
    debugPrint('ALERT KEY: ${message['key']}');
    final asset = _alertAssets[message['key']];
    if (asset != null) {
      debugPrint('PLAYING ASSET: $asset');
      await audioQueue.playLocal(
        asset,
        priority: AudioPriority.high,
      );
    }
    final label = _alertLabels[message['key']] ?? 'Alert';
    onHazardStateChanged?.call(label);
    // Danger alert overrides whatever mode the UI is in
    onModeOverride?.call('danger');
    break;

  case 'audio':
    final url = message['url'];
    if (url is String && url.isNotEmpty) {
      final sourceUrl = Uri.parse(url).hasScheme
          ? url
          : '$controllerHttpBase$url';

      debugPrint('REMOTE AUDIO URL: $sourceUrl');
      await audioQueue.playRemote(
        sourceUrl,
        priority: _audioPriority(
          (message['priority'] as num?)?.toInt() ?? 2,
        ),
      );
    }
    break;

  case 'audio_stop':
    await audioQueue.stop();
    break;
}
  }

  Future<void> dispose() async {
    webSocket.connectionStatus.removeListener(_handleStatus);
    await _messages?.cancel();
    await audioQueue.stop();
  }

  static const _alertAssets = <String, String>{
    'OBSTACLE_NEAR': 'assets/audio/danger_alert.mp3',
    'OBSTACLE_MID': 'assets/audio/danger_alert.mp3',
    'PERSON_NEAR': 'assets/audio/person_alert.mp3',
    'VEHICLE_NEAR': 'assets/audio/vehicle_alert.mp3',
    'DOG_NEAR': 'assets/audio/dog_alert.mp3',
    'STREAM_LOST': 'assets/audio/danger_alert.mp3',
  };

  static const _alertLabels = <String, String>{
    'OBSTACLE_NEAR': 'Alert: Obstacle Near',
    'OBSTACLE_MID': 'Alert: Obstacle Mid',
    'PERSON_NEAR': 'Alert: Person Near',
    'VEHICLE_NEAR': 'Alert: Vehicle Near',
    'DOG_NEAR': 'Alert: Dog Near',
    'STREAM_LOST': 'Alert: Stream Lost',
  };

  AudioPriority _audioPriority(int controllerPriority) {
    if (controllerPriority <= 0) return AudioPriority.high;
    if (controllerPriority == 1) return AudioPriority.medium;
    return AudioPriority.low;
  }
}
