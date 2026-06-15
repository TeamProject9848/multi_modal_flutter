import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../providers/app_providers.dart';
import '../services/webrtc_service.dart';

class LiveCameraPreview extends ConsumerWidget {
  const LiveCameraPreview({super.key, this.height = 220});

  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Preview(service: ref.watch(webrtcServiceProvider), height: height);
  }
}

class _Preview extends StatefulWidget {
  const _Preview({required this.service, this.height});

  final WebRTCService service;
  final double? height;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  StreamSubscription<MediaStream>? _subscription;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _Preview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) _attach();
  }

  Future<void> _attach() async {
    await _subscription?.cancel();
    if (!_ready) {
      await _renderer.initialize();
      _ready = true;
    }
    _renderer.srcObject = widget.service.currentStream;
    _subscription = widget.service.localStream.listen((stream) {
      if (mounted) setState(() => _renderer.srcObject = stream);
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _renderer.srcObject == null
            ? const ColoredBox(
                color: Colors.white10,
                child: Center(child: CircularProgressIndicator()),
              )
            : RTCVideoView(
                _renderer,
                mirror: false,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
      ),
    );
  }
}
