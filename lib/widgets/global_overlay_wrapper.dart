
import 'package:flutter/material.dart';
import '../services/overlay_service.dart';

class GlobalOverlayWrapper extends StatefulWidget {
  final Widget child;

  const GlobalOverlayWrapper({super.key, required this.child});

  @override
  State<GlobalOverlayWrapper> createState() => _GlobalOverlayWrapperState();
}

class _GlobalOverlayWrapperState extends State<GlobalOverlayWrapper> {
  @override
  void initState() {
    super.initState();
    // 렌더링 완료 후 Overlay 컨텍스트 등록
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OverlayService().registerOverlay(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}