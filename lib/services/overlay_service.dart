/// overlay_service.dart
import 'package:flutter/material.dart';

class OverlayService {
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  BuildContext? _overlayContext;
  OverlayEntry? _callOverlay;

  /// GlobalOverlayWrapper에서 호출
  void registerOverlay(BuildContext context) {
    _overlayContext = context;
  }

  /// 오버레이 표시
  void show(Widget widget) {
    remove();

    if (_overlayContext == null) {
      debugPrint('[OverlayService] context가 등록되지 않음');
      return;
    }

    _callOverlay = OverlayEntry(
      builder: (_) => widget,
    );

    Overlay.of(_overlayContext!).insert(_callOverlay!);
  }

  /// 오버레이 제거
  void remove() {
    _callOverlay?.remove();
    _callOverlay?.dispose();
    _callOverlay = null;
  }

  bool get isShowing => _callOverlay != null;
}