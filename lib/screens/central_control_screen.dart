import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quepilot_client_01/screens/chattings_screen.dart';
import 'package:quepilot_client_01/screens/project_list_screen.dart';
import 'package:quepilot_client_01/screens/settings_screen.dart';
import 'package:quepilot_client_01/services/socket_service.dart';
import 'package:quepilot_client_01/services/web_rtc_service.dart';

import '../dialog/active_call_overlay.dart';
import '../dialog/incoming_call_overlay.dart';
import '../models/message_model.dart';
import '../services/overlay_service.dart';

enum _CallPhase { idle, incoming, connecting, active }

class CentralControlScreen extends StatefulWidget {
  const CentralControlScreen({super.key});

  @override
  State<CentralControlScreen> createState() => _CentralControlScreenState();
}

class _CentralControlScreenState extends State<CentralControlScreen>
    with SingleTickerProviderStateMixin {
  final socketService = SocketService();
  final overlayService = OverlayService();
  final List<StreamSubscription> _subs = [];

  int _selectedMenuIndex = 0;
  late TabController _tabController;

  // 채팅
  void Function(MessageData)? _chattingsScreenOnMessageReceived;
  int _unreadCount = 0;
  final int _chattingsScreenNavIndex = 1;

  // ★ 개인 통화
  WebRTCService? _directCallWebRTC;
  _CallPhase _callPhase = _CallPhase.idle;
  String? _callId;
  String? _callPeerId;
  String? _callPeerName;
  bool _isCallMuted = false;
  final ValueNotifier<bool> _isCallMutedNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    print('central_control_screen initState()');

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_tabListener);

    // _setupChattingsListener();
    // _setupDirectCallListeners();

    _subs.add(socketService.incomingDirectCall.listen((data) {
      print("📳 [IncomingCall] ${data.callerName} (${data.callerId})");

      if (_callPhase != _CallPhase.idle) {
        socketService.rejectDirectCall(data.callId, (_) {});
        return;
      }

      setState(() {
        _callPhase = _CallPhase.incoming;
        _callId = data.callId;
        _callPeerId = data.callerId;
        _callPeerName = data.callerName;
      });

      _showIncomingOverlay();
    }));

    _subs.add(socketService.directCallCancelled.listen((data) {
      if (data.callId != _callId) return;
      _resetCallState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${data.callerName} 님이 전화를 취소했습니다.')),
        );
      }
    }));

    _subs.add(socketService.directCallEnded.listen((data) {
      if (data.callId != _callId) return;
      _cleanupCall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data.reason == 'disconnected'
                ? '${data.endedByName} 님의 연결이 끊어졌습니다.'
                : '${data.endedByName} 님이 통화를 종료했습니다.'),
          ),
        );
      }
    }));

    _subs.add(socketService.receivePersonalMessage.listen((data) {
      _chattingsScreenOnMessageReceived?.call(data);
      if (_selectedMenuIndex != _chattingsScreenNavIndex) {
        setState(() => _unreadCount++);
      }
    }));
  }

  @override
  void dispose() {

    print('central_control_screen dispose()');

    _tabController.removeListener(_tabListener);

    // socketService.offAllDirectCallListeners();
    // socketService.offReceivePersonalMessage();

    if (_callId != null) {
      socketService.endDirectCall(_callId!, null);
    }
    _directCallWebRTC?.dispose();
    overlayService.remove();

    for (final sub in _subs){
      sub.cancel();
    }

    super.dispose();
  }

  void _tabListener() {
    setState(() {
      _selectedMenuIndex = _tabController.index;
      if (_selectedMenuIndex == _chattingsScreenNavIndex) {
        _unreadCount = 0;
      }
    });
  }

  void _showIncomingOverlay(){
    overlayService.show(
      IncomingCallOverlay(
          callId: _callId!,
          callerId: _callPeerId!,
          callerName: _callPeerName ?? 'Unknown',
          onAccept: _acceptCall,
          onReject: _rejectCall,
      ),
    );
  }

  void _showActiveCallOverlay({bool isConnecting = false}) {
    overlayService.show(
      ActiveCallOverlay(
          peerName: _callPeerName ?? 'unKnown',
          isMutedNotifier: _isCallMutedNotifier,
          isConnecting: isConnecting,
          onEnd: _endCall,
          onToggleMute: _toggleCallMute,
      ),
    );
  }

  // void _setupChattingsListener() {
  //   socketService.onReceivePersonalMessage((data) {
  //     _chattingsScreenOnMessageReceived?.call(data);
  //     if (_selectedMenuIndex != _chattingsScreenNavIndex) {
  //       setState(() => _unreadCount++);
  //     }
  //   });
  // }

  // ========================================
  // ★ 개인 통화 리스너
  // ========================================
  // void _setupDirectCallListeners() {
    // 전화 수신
    // socketService.onIncomingDirectCall((callId, callerId, callerName) {
    //   print('📳 [IncomingCall] $callerName ($callerId)');
    //
    //   if (_callPhase != _CallPhase.idle) {
    //     socketService.rejectDirectCall(callId, (_) {});
    //     return;
    //   }
    //
    //   setState(() {
    //     _callPhase = _CallPhase.incoming;
    //     _callId = callId;
    //     _callPeerId = callerId;
    //     _callPeerName = callerName;
    //   });
    // });

    // 발신자 취소
    // socketService.onDirectCallCancelled((callId, callerId, callerName) {
    //   if (callId != _callId) return;
    //   _resetCallState();
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text('$callerName 님이 전화를 취소했습니다.')),
    //     );
    //   }
    // });

    // 상대가 종료
    // socketService.onDirectCallEnded((callId, endedBy, endedByName, reason) {
    //   if (callId != _callId) return;
    //   _cleanupCall();
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(reason == 'disconnected'
    //             ? '$endedByName 님의 연결이 끊어졌습니다.'
    //             : '$endedByName 님이 통화를 종료했습니다.'),
    //       ),
    //     );
    //   }
    // });
  // }

  // ========================================
  // 수락
  // ========================================
  void _acceptCall() async {
    if (_callId == null || _callPeerId == null) return;

    // ★ 기존 WebRTCService를 direct 모드로 생성
    _directCallWebRTC = WebRTCService(socketService);
    _directCallWebRTC!.setDirectMode(_callId!);

    _directCallWebRTC!.onPeerConnected = () {
      if (mounted) {
        setState(() => _callPhase = _CallPhase.active);
        _showActiveCallOverlay(isConnecting:false);
        print('🔗 [DirectCall] 연결 완료');
      }
    };

    _directCallWebRTC!.onPeerDisconnected = () {
      print('🔌 [DirectCall] 연결 해제');
      _cleanupCall();
    };

    final localStream = await _directCallWebRTC!.initLocalStream();
    if (localStream == null) {
      _directCallWebRTC?.dispose();
      _directCallWebRTC = null;
      socketService.rejectDirectCall(_callId!, (_) {});
      _resetCallState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ 마이크 권한이 필요합니다.')),
        );
      }
      return;
    }

    setState(() => _callPhase = _CallPhase.connecting);
    _showActiveCallOverlay(isConnecting:true);

    // 서버에 수락 → admin이 Offer를 보냄 → WebRTCService가 자동 처리
    socketService.acceptDirectCall(
      _callId!,
      socketService.loggedInUser.name,
          (success) {
        if (!success && mounted) {
          _cleanupCall();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('통화 수락 실패')),
          );
        }
      },
    );
  }

  // ========================================
  // 거절
  // ========================================
  void _rejectCall() {
    if (_callId == null) return;

    final callId = _callId;

    _resetCallState();
    
    socketService.rejectDirectCall(callId!, (_) {});
    final webrtc= _directCallWebRTC;
    _directCallWebRTC = null;
    webrtc?.dispose();
  }

  // ========================================
  // 종료
  // ========================================
  void _endCall() {
    if (_callId == null) return;
    socketService.endDirectCall(_callId!, (_) {});
    _cleanupCall();
  }

  // ========================================
  // 음소거
  // ========================================
  void _toggleCallMute() {
    _directCallWebRTC?.toggleAudio(_isCallMuted);
    setState(() {
      _isCallMuted = !_isCallMuted;
      _isCallMutedNotifier.value = _isCallMuted;
    });
  }

  // ========================================
  // 상태 초기화
  // ========================================
  void _resetCallState() {
    overlayService.remove();
    setState(() {
      _callPhase = _CallPhase.idle;
      _callId = null;
      _callPeerId = null;
      _callPeerName = null;
      _isCallMuted = false;
      _isCallMutedNotifier.value = false;
    });
  }

  void _cleanupCall() async {
    _resetCallState();

    await _directCallWebRTC?.dispose();
    _directCallWebRTC = null;
  }

  // ========================================
  // Build
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[850],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[500],
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedMenuIndex,
        onTap: (int index) {
          _tabController.animateTo(index);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
            icon: _unreadCount > 0
                ? Badge(label: Text('$_unreadCount'), child: const Icon(Icons.chat))
                : const Icon(Icons.chat),
            label: '채팅',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
      body: Stack(
        children: [
          // 메인 콘텐츠
          TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: [
              ProjectListScreen(),
              ChattingsScreen(
                onRegisterCallback: (callback) {
                  _chattingsScreenOnMessageReceived = callback;
                },
              ),
              SettingsScreen(),
            ],
          ),
          //
          // // ★ 수신 오버레이
          // if (_callPhase == _CallPhase.incoming)
          //   IncomingCallOverlay(
          //     callId: _callId!,
          //     callerId: _callPeerId!,
          //     callerName: _callPeerName ?? 'Unknown',
          //     onAccept: _acceptCall,
          //     onReject: _rejectCall,
          //   ),
          //
          // // ★ 통화 중 상단 바
          // if (_callPhase == _CallPhase.connecting || _callPhase == _CallPhase.active)
          //   ActiveCallOverlay(
          //     peerName: _callPeerName ?? 'Unknown',
          //     isMuted: _isCallMuted,
          //     isConnecting: _callPhase == _CallPhase.connecting,
          //     onEnd: _endCall,
          //     onToggleMute: _toggleCallMute,
          //   ),
        ],
      ),
    );
  }
}