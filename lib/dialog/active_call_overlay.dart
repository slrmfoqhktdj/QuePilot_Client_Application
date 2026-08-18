import 'dart:async';
import 'package:flutter/material.dart';

class ActiveCallOverlay extends StatefulWidget {
  final String peerName;
  final ValueNotifier<bool>? isMutedNotifier;
  final bool isConnecting; // WebRTC 연결 중
  final VoidCallback onEnd;
  final VoidCallback onToggleMute;

  bool get isMuted => isMutedNotifier?.value ?? false;

  const ActiveCallOverlay({
    Key? key,
    required this.peerName,
    this.isMutedNotifier,
    this.isConnecting = false,
    required this.onEnd,
    required this.onToggleMute,
  }) : super(key: key);

  @override
  State<ActiveCallOverlay> createState() => _ActiveCallOverlayState();
}

class _ActiveCallOverlayState extends State<ActiveCallOverlay> {
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    widget.isMutedNotifier?.addListener(_onMuteChanged);
  }

  void _onMuteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.isMutedNotifier?.removeListener(_onMuteChanged);
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isConnecting
                  ? Colors.orange.shade800
                  : Colors.green.shade800,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: (widget.isConnecting ? Colors.orange : Colors.green)
                      .withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 상태 아이콘
                Icon(
                  widget.isConnecting ? Icons.phone_forwarded : Icons.phone_in_talk,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),

                // 이름 + 시간
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.isConnecting
                          ? '연결 중...'
                          : '통화 중 · ${_formatTime(_elapsedSeconds)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // 음소거
                GestureDetector(
                  onTap: widget.onToggleMute,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.isMuted ? Colors.red.shade700 : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 종료
                GestureDetector(
                  onTap: widget.onEnd,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
