import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  WebRTCService({required this.stunServer});

  final String stunServer;
  final StreamController<MediaStream> _localStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<RTCPeerConnectionState> _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isFrontCamera = false;

  Stream<MediaStream> get localStream => _localStreamController.stream;
  Stream<RTCPeerConnectionState> get connectionState =>
      _connectionStateController.stream;
  MediaStream? get currentStream => _localStream;

  Future<void> initialize({bool useFrontCamera = false}) async {
    if (_localStream != null && _isFrontCamera != useFrontCamera) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    if (_localStream == null) {
      await _createMediaStream(useFrontCamera: useFrontCamera);
    }
    await _createPeerConnection();
  }

  Future<void> switchCamera() async {
    final stream = _localStream;
    if (stream != null && stream.getVideoTracks().isNotEmpty) {
      await Helper.switchCamera(stream.getVideoTracks()[0]);
      _isFrontCamera = !_isFrontCamera;
    }
  }

  Future<void> _createMediaStream({required bool useFrontCamera}) async {
    final constraints = <String, dynamic>{
      'audio': false,
      'video': {
        'facingMode': useFrontCamera ? 'user' : 'environment',
        'width': {'ideal': 720},
        'height': {'ideal': 1280},
        'frameRate': {'ideal': 30},
      },
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _isFrontCamera = useFrontCamera;
    _localStreamController.add(_localStream!);
  }

  Future<void> _createPeerConnection() async {
    await _peerConnection?.close();
    final configuration = <String, dynamic>{
      'iceServers': [
        if (stunServer.trim().isNotEmpty) {'urls': stunServer.trim()},
      ],
    };
    final peer = await createPeerConnection(configuration);
    _peerConnection = peer;
    peer.onConnectionState = _connectionStateController.add;

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await peer.addTrack(track, stream);
      }
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    final peer = _peerConnection;
    if (peer == null) throw StateError('WebRTC has not been initialized');
    final offer = await peer.createOffer({'offerToReceiveAudio': false});
    await peer.setLocalDescription(offer);
    await _waitForIceGathering(peer);
    return (await peer.getLocalDescription())!;
  }

  Future<void> _waitForIceGathering(RTCPeerConnection peer) async {
    if (await peer.getIceGatheringState() ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    peer.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  Future<void> acceptAnswer({required String sdp, required String type}) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(sdp, type),
    );
  }

  Future<void> dispose() async {
    await _peerConnection?.close();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _localStreamController.close();
    await _connectionStateController.close();
  }
}
