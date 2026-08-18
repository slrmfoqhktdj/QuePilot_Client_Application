import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'socket_service.dart';

enum SignalingMode { room, direct }

class WebRTCService {
  final SocketService socketService;

  // ★ 시그널링 구독 전용 리스트 (모드 전환 시 취소 후 재등록)
  final List<StreamSubscription> _signalingSubs = [];

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, List<Map<String, dynamic>>> _pendingIceCandidates = {};

  Function(String userId, MediaStream stream)? onRemoteStreamAdded;
  Function(String userId)? onRemoteStreamRemoved;

  // 오디오 설정
  double _masterVolume = 1.0;
  double _microphoneGain = 1.0;
  bool _isMicMuted = false;

  // 개별 볼륨
  final Map<String, double> _peerVolumes = {};
  final Map<String, bool> _peerMuted = {};
  Function(String userId, double volume)? onPeerVolumeChanged;

  double get masterVolume => _masterVolume;
  double get microphoneGain => _microphoneGain;
  bool get isMicMuted => _isMicMuted;
  Map<String, double> get peerVolumes => Map.unmodifiable(_peerVolumes);
  Map<String, bool> get peerMuted => Map.unmodifiable(_peerMuted);

  // 시그널링 모드
  SignalingMode _signalingMode = SignalingMode.room;
  String? _directCallId;

  SignalingMode get signalingMode => _signalingMode;
  String? get directCallId => _directCallId;

  // WebRTC 연결 상태 콜백
  Function()? onPeerConnected;
  Function()? onPeerDisconnected;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  WebRTCService(this.socketService);

  // ========================================
  // 시그널링 모드 설정
  // ========================================

  /// 룸 통화 모드로 설정 후 시그널링 시작
  void setRoomMode() {
    _signalingMode = SignalingMode.room;
    _directCallId = null;
    _rebindSignalingListeners();
    print('📡 [WebRTC] 시그널링 모드: ROOM');
  }

  /// 개인 통화 모드로 설정 후 시그널링 시작
  void setDirectMode(String callId) {
    _signalingMode = SignalingMode.direct;
    _directCallId = callId;
    _rebindSignalingListeners();
    print('📡 [WebRTC] 시그널링 모드: DIRECT (callId=$callId)');
  }

  // ========================================
  // ★ 시그널링 구독 관리
  // ========================================

  /// 기존 시그널링 구독 취소 → 현재 모드에 맞게 재등록
  void _rebindSignalingListeners() {
    // 기존 구독 전부 취소
    for (final sub in _signalingSubs) {
      sub.cancel();
    }
    _signalingSubs.clear();

    if (_signalingMode == SignalingMode.room) {
      _bindRoomSignaling();
    } else {
      _bindDirectSignaling();
    }
  }

  void _bindRoomSignaling() {
    _signalingSubs.add(
      socketService.webRTCOffer.listen((event) async {
        print('📥 [Room] Offer 수신: ${event.from}');
        await _handleOffer(event.from, event.payload);
      }),
    );

    _signalingSubs.add(
      socketService.webRTCAnswer.listen((event) async {
        print('📥 [Room] Answer 수신: ${event.from}');
        await _handleAnswer(event.from, event.payload);
      }),
    );

    _signalingSubs.add(
      socketService.webRTCIce.listen((event) async {
        print('🧊 [Room] ICE 수신: ${event.from}');
        await _handleIceCandidate(event.from, event.payload);
      }),
    );
  }

  void _bindDirectSignaling() {
    _signalingSubs.add(
      socketService.directWebRTCOffer.listen((event) async {
        if (event.callId != _directCallId) return;
        print('📥 [Direct] Offer 수신: ${event.from}');
        await _handleOffer(event.from, event.payload);
      }),
    );

    _signalingSubs.add(
      socketService.directWebRTCAnswer.listen((event) async {
        if (event.callId != _directCallId) return;
        print('📥 [Direct] Answer 수신: ${event.from}');
        await _handleAnswer(event.from, event.payload);
      }),
    );

    _signalingSubs.add(
      socketService.directWebRTCIce.listen((event) async {
        if (event.callId != _directCallId) return;
        print('🧊 [Direct] ICE 수신: ${event.from}');
        await _handleIceCandidate(event.from, event.payload);
      }),
    );
  }

  // ========================================
  // ★ 시그널링 전송 (모드에 따라 분기)
  // ========================================

  void _sendOffer(String peerId, Map<String, dynamic> offer) {
    if (_signalingMode == SignalingMode.direct && _directCallId != null) {
      socketService.sendDirectWebRTCOffer(_directCallId!, peerId, offer);
      print('📤 [Direct] Offer → $peerId');
    } else {
      socketService.sendWebRTCOffer(peerId, offer);
      print('📤 [Room] Offer → $peerId');
    }
  }

  void _sendAnswer(String peerId, Map<String, dynamic> answer) {
    if (_signalingMode == SignalingMode.direct && _directCallId != null) {
      socketService.sendDirectWebRTCAnswer(_directCallId!, peerId, answer);
      print('📤 [Direct] Answer → $peerId');
    } else {
      socketService.sendWebRTCAnswer(peerId, answer);
      print('📤 [Room] Answer → $peerId');
    }
  }

  void _sendIceCandidate(String peerId, Map<String, dynamic> candidate) {
    if (_signalingMode == SignalingMode.direct && _directCallId != null) {
      socketService.sendDirectWebRTCIceCandidate(_directCallId!, peerId, candidate);
    } else {
      socketService.sendWebRTCIceCandidate(peerId, candidate);
    }
  }

  // ========================================
  // 로컬 스트림
  // ========================================

  Future<MediaStream?> initLocalStream() async {
    try {
      PermissionStatus status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('❌ 마이크 권한 거부');
        return null;
      }

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      print('✅ 로컬 오디오 스트림 초기화 완료');
      final audioTracks = _localStream!.getAudioTracks();
      print('   오디오 트랙 수: ${audioTracks.length}');
      for (var track in audioTracks) {
        print('   - ${track.label}: enabled=${track.enabled}');
      }
      return _localStream;
    } catch (e) {
      print('❌ 로컬 스트림 초기화 실패: $e');
      return null;
    }
  }

  // ========================================
  // 볼륨 / 마이크 제어
  // ========================================

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    _remoteStreams.forEach((peerId, stream) {
      final peerVol = _peerVolumes[peerId] ?? 1.0;
      final isMuted = _peerMuted[peerId] ?? false;
      _applyVolume(stream, isMuted ? 0.0 : peerVol * _masterVolume);
    });
    print('🔊 마스터 볼륨: ${(_masterVolume * 100).toInt()}%');
  }

  void setMicrophoneGain(double gain) {
    _microphoneGain = gain.clamp(0.0, 2.0);
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        if (_microphoneGain == 0.0) {
          track.enabled = false;
        } else if (!_isMicMuted) {
          track.enabled = true;
        }
      }
    }
    print('🎤 마이크 게인: ${(_microphoneGain * 100).toInt()}%');
  }

  void toggleAudio(bool enabled) {
    _isMicMuted = !enabled;
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = enabled;
      }
      print(enabled ? '🔊 음소거 해제' : '🔇 음소거');
    }
  }

  void setPeerVolume(String peerId, double volume) {
    _peerVolumes[peerId] = volume.clamp(0.0, 1.0);
    final stream = _remoteStreams[peerId];
    if (stream != null) {
      final isMuted = _peerMuted[peerId] ?? false;
      _applyVolume(stream, isMuted ? 0.0 : volume * _masterVolume);
    }
    onPeerVolumeChanged?.call(peerId, volume);
    print('🔊 [$peerId] 개별 볼륨: ${(volume * 100).toInt()}%');
  }

  double getPeerVolume(String peerId) => _peerVolumes[peerId] ?? 1.0;

  void togglePeerMute(String peerId) {
    final isMuted = !(_peerMuted[peerId] ?? false);
    _peerMuted[peerId] = isMuted;
    final stream = _remoteStreams[peerId];
    if (stream != null) {
      if (isMuted) {
        _applyVolume(stream, 0.0);
      } else {
        final peerVol = _peerVolumes[peerId] ?? 1.0;
        _applyVolume(stream, peerVol * _masterVolume);
      }
    }
    print(isMuted ? '🔇 [$peerId] 음소거' : '🔊 [$peerId] 음소거 해제');
  }

  bool isPeerMuted(String peerId) => _peerMuted[peerId] ?? false;

  void _applyVolume(MediaStream stream, double volume) {
    for (var track in stream.getAudioTracks()) {
      if (volume == 0.0) {
        track.enabled = false;
      } else {
        track.enabled = true;
        Helper.setVolume(volume, track);
      }
    }
  }

  // ========================================
  // 피어 연결
  // ========================================

  Future<RTCPeerConnection?> _createPeerConnection(String peerId) async {
    try {
      if (_peerConnections.containsKey(peerId)) {
        final existingPc = _peerConnections[peerId]!;
        final connectionState = await existingPc.getConnectionState();
        final signalingState = await existingPc.getSignalingState();

        print('⚠️ 기존 피어 연결: $peerId (연결=$connectionState, 시그널링=$signalingState)');

        if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
            signalingState == RTCSignalingState.RTCSignalingStateStable) {
          print('✅ 기존 연결 재사용: $peerId');
          return existingPc;
        }

        if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            connectionState == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
            connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          print('🔄 기존 연결 제거 후 재생성: $peerId');
          await existingPc.close();
          _peerConnections.remove(peerId);
          _remoteStreams.remove(peerId);
        } else {
          print('✅ 기존 연결 재사용 (연결 중): $peerId');
          return existingPc;
        }
      }

      print('🔗 피어 연결 생성: $peerId');

      final pc = await createPeerConnection(_iceServers);

      // 로컬 스트림 추가
      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          pc.addTrack(track, _localStream!);
        }
        print('✅ 로컬 오디오 트랙 추가: $peerId');
      } else {
        print('⚠️ 로컬 스트림 없음');
      }

      // ICE Candidate
      pc.onIceCandidate = (RTCIceCandidate candidate) {
        _sendIceCandidate(peerId, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      pc.onIceGatheringState = (RTCIceGatheringState state) {
        print('🧊 ICE Gathering: $peerId → $state');
      };

      pc.onConnectionState = (RTCPeerConnectionState state) {
        print('🔗 연결 상태: $peerId → $state');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          onPeerConnected?.call();
          _startStatsDump(peerId);
        }
      };

      pc.onSignalingState = (RTCSignalingState state) {
        print('📡 시그널링: $peerId → $state');
      };

      pc.onTrack = (RTCTrackEvent event) {
        print('📥 원격 트랙 수신: $peerId (${event.track.kind})');
        if (event.streams.isNotEmpty) {
          final remoteStream = event.streams[0];
          _remoteStreams[peerId] = remoteStream;

          _peerVolumes.putIfAbsent(peerId, () => 1.0);
          _peerMuted.putIfAbsent(peerId, () => false);

          final peerVol = _peerVolumes[peerId]!;
          final isMuted = _peerMuted[peerId]!;
          _applyVolume(remoteStream, isMuted ? 0.0 : peerVol * _masterVolume);

          onRemoteStreamAdded?.call(peerId, remoteStream);
        }
      };

      _peerConnections[peerId] = pc;
      print('✅ 피어 연결 생성 완료: $peerId');
      return pc;
    } catch (e) {
      print('❌ 피어 연결 생성 실패: $peerId - $e');
      return null;
    }
  }

  Future<void> createOffer(String peerId) async {
    try {
      print('📤 Offer 생성: $peerId');

      final existingPc = _peerConnections[peerId];
      if (existingPc != null) {
        final signalingState = await existingPc.getSignalingState();
        if (signalingState == RTCSignalingState.RTCSignalingStateStable) {
          print('ℹ️ 이미 안정화 (건너뜀)');
          return;
        }
        if (signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          print('ℹ️ 이미 Offer 보낸 상태 (건너뜀)');
          return;
        }
      }

      final pc = await _createPeerConnection(peerId);
      if (pc == null) return;

      RTCSessionDescription offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await pc.setLocalDescription(offer);

      _sendOffer(peerId, {
        'type': offer.type,
        'sdp': offer.sdp,
      });

      print('✅ Offer 전송 완료: $peerId');
    } catch (e) {
      print('❌ Offer 생성 실패: $peerId - $e');
    }
  }

  Future<void> _handleOffer(String peerId, dynamic offerData) async {
    try {
      print('📥 Offer 처리: $peerId');
      print('🔍 [Client] _handleOffer 도착: from=$peerId');
      print('🔍 [Client] offerData 있음?: ${offerData != null}');
      print('🔍 [Client] PC 존재?: ${_peerConnections.containsKey(peerId)}');

      if (offerData == null || offerData['sdp'] == null || offerData['type'] == null) {
        print('❌ Offer 데이터 null: $peerId');
        return;
      }

      var pc = _peerConnections[peerId];
      if (pc != null) {
        final signalingState = await pc.getSignalingState();
        if (signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          print('⚠️ Glare 감지: $peerId — PC 재생성 후 remote offer 수락');
          await pc.close();
          _peerConnections.remove(peerId);
          pc = null;
        }
      }

      pc = await _createPeerConnection(peerId);
      if (pc == null) return;

      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      await pc.setRemoteDescription(offer);

      await _flushPendingIceCandidates(peerId);

      RTCSessionDescription answer = await pc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await pc.setLocalDescription(answer);

      _sendAnswer(peerId, {
        'type': answer.type,
        'sdp': answer.sdp,
      });

      print('✅ Answer 전송 완료: $peerId');
    } catch (e) {
      print('❌ Offer 처리 실패: $peerId - $e');
    }
  }

  Future<void> _handleAnswer(String peerId, dynamic answerData) async {
    try {
      final pc = _peerConnections[peerId];
      if (pc == null) {
        print('⚠️ 피어 연결 없음: $peerId');
        return;
      }

      final signalingState = await pc.getSignalingState();
      if (signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        print('⚠️ Answer 받을 수 없는 상태: $signalingState');
        return;
      }

      final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
      await pc.setRemoteDescription(answer);

      await _flushPendingIceCandidates(peerId);

      print('✅ Answer 처리 완료: $peerId');
    } catch (e) {
      print('❌ Answer 처리 실패: $peerId - $e');
    }
  }

  Future<void> _handleIceCandidate(String peerId, dynamic candidateData) async {
    try {
      final pc = _peerConnections[peerId];
      if (pc == null) {
        print('⚠️ ICE: 피어 연결 없음 - $peerId (대기열에 추가)');
        _pendingIceCandidates.putIfAbsent(peerId, () => []).add(candidateData);
        return;
      }

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      try {
        await pc.addCandidate(candidate);
        print('✅ ICE Candidate 추가: $peerId');
      } catch (e) {
        print('⚠️ ICE Candidate 추가 실패 (대기열에 추가): $peerId - $e');
        _pendingIceCandidates.putIfAbsent(peerId, () => []).add(candidateData);
      }
    } catch (e) {
      print('❌ ICE Candidate 실패: $peerId - $e');
    }
  }

  Future<void> _flushPendingIceCandidates(String peerId) async {
    final pending = _pendingIceCandidates.remove(peerId);
    if (pending == null || pending.isEmpty) return;

    final pc = _peerConnections[peerId];
    if (pc == null) {
      _pendingIceCandidates[peerId] = pending;
      return;
    }

    for (final data in pending) {
      try {
        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await pc.addCandidate(candidate);
        print('✅ 대기 중이던 ICE Candidate 추가: $peerId');
      } catch (e) {
        print('❌ 대기 중이던 ICE Candidate 추가 실패: $peerId - $e');
      }
    }
  }

  Future<void> connectToExistingPeers(List<dynamic> existingPeers) async {
    print('🔗 기존 참여자 연결: ${existingPeers.length}명');
    for (var peer in existingPeers) {
      try {
        final peerId = peer['userId'] as String;
        await createOffer(peerId);
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('   ❌ 연결 실패: $e');
      }
    }
  }

  void removePeerConnection(String peerId) {
    _peerConnections[peerId]?.close();
    _peerConnections.remove(peerId);
    _remoteStreams.remove(peerId);
    _pendingIceCandidates.remove(peerId);
    _peerVolumes.remove(peerId);
    _peerMuted.remove(peerId);
    onRemoteStreamRemoved?.call(peerId);
    print('🗑️ 피어 연결 제거: $peerId');
  }

  MediaStream? getRemoteStream(String peerId) => _remoteStreams[peerId];
  Map<String, MediaStream> get remoteStreams => _remoteStreams;

  // ========================================
  // 진단용 getStats 로그
  // ========================================

  Timer? _statsTimer;
  int _statsDumpCount = 0;

  void _startStatsDump(String peerId) {
    _statsTimer?.cancel();
    _statsDumpCount = 0;
    _logAudioStats(peerId, '[Client]');
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _statsDumpCount++;
      await _logAudioStats(peerId, '[Client]');
      if (_statsDumpCount >= 10) {
        timer.cancel();
      }
    });
  }

  Future<void> _logAudioStats(String peerId, String tag) async {
    final pc = _peerConnections[peerId];
    if (pc == null) {
      print('$tag [Stats] 피어 연결 없음: $peerId');
      return;
    }
    try {
      final reports = await pc.getStats();
      for (final stat in reports) {
        final values = stat.values;
        final mediaType = values['mediaType']?.toString() ?? '';
        final kind = values['kind']?.toString() ?? '';
        if (mediaType == 'audio' || kind == 'audio') {
          final direction = stat.type.contains('inbound')
              ? '⬇ 수신'
              : (stat.type.contains('outbound') ? '⬆ 송신' : '?');
          print('$tag [Stats] $direction audio '
              'type=${stat.type} '
              'bytesSent=${values['bytesSent']} '
              'packetsSent=${values['packetsSent']} '
              'bytesReceived=${values['bytesReceived']} '
              'packetsReceived=${values['packetsReceived']} '
              'audioLevel=${values['audioLevel']} '
              'totalAudioEnergy=${values['totalAudioEnergy']} '
              'jitter=${values['jitter']}');
        }
      }
    } catch (e) {
      print('$tag [Stats] getStats 실패: $peerId - $e');
    }
  }

  // ========================================
  // 정리
  // ========================================

  Future<void> dispose() async {
    print('🧹 WebRTC 정리 시작');
    _statsTimer?.cancel();

    // ★ 시그널링 구독 취소
    for (final sub in _signalingSubs) {
      sub.cancel();
    }
    _signalingSubs.clear();

    // 피어 연결 종료
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    // 로컬 스트림 종료
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }

    _remoteStreams.clear();
    _pendingIceCandidates.clear();
    _peerVolumes.clear();
    _peerMuted.clear();

    onPeerConnected = null;
    onPeerDisconnected = null;
    onRemoteStreamAdded = null;
    onRemoteStreamRemoved = null;
    onPeerVolumeChanged = null;

    _signalingMode = SignalingMode.room;
    _directCallId = null;

    print('✅ WebRTC 정리 완료');
  }
}



// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'socket_service.dart';
//
// class WebRTCService {
//   final SocketService socketService;
//
//   MediaStream? _localStream;
//   final Map<String, RTCPeerConnection> _peerConnections = {};
//   final Map<String, MediaStream> _remoteStreams = {};
//
//   Function(String userId, MediaStream stream)? onRemoteStreamAdded;
//   Function(String userId)? onRemoteStreamRemoved;
//
//   // ✅ 오디오 설정 저장
//   double _masterVolume = 1.0;
//   double _microphoneGain = 1.0;
//   bool _isMicMuted = false;
//
//   // ✅ 클라이언트별 개별 볼륨
//   final Map<String, double> _peerVolumes = {};           // userId → 볼륨 (0.0 ~ 1.0)
//   final Map<String, bool> _peerMuted = {};               // userId → 음소거 여부
//   Function(String userId, double volume)? onPeerVolumeChanged;
//
//   // getter
//   double get masterVolume => _masterVolume;
//   double get microphoneGain => _microphoneGain;
//   bool get isMicMuted => _isMicMuted;
//   Map<String, double> get peerVolumes => Map.unmodifiable(_peerVolumes);
//   Map<String, bool> get peerMuted => Map.unmodifiable(_peerMuted);
//
//   final Map<String, dynamic> _iceServers = {
//     'iceServers': [
//       {'urls': 'stun:stun.l.google.com:19302'},
//       {'urls': 'stun:stun1.l.google.com:19302'},
//       {'urls': 'stun:stun2.l.google.com:19302'},
//       {'urls': 'stun:stun3.l.google.com:19302'},
//       {'urls': 'stun:stun4.l.google.com:19302'},
//     ]
//   };
//
//   WebRTCService(this.socketService) {
//     _setupSignalingListeners();
//   }
//
//   // 🔧 로컬 스트림 초기화 (음성만)
//   Future<MediaStream?> initLocalStream() async {
//     try {
//       // 마이크 권한 요청
//       PermissionStatus status = await Permission.microphone.request();
//       if (status != PermissionStatus.granted) {
//         print('❌ 마이크 권한이 거부되었습니다');
//         return null;
//       }
//
//       // 음성만 가져오기
//       final Map<String, dynamic> constraints = {
//         'audio': true,
//         'video': false,  // 영상 비활성화
//       };
//
//       _localStream = await navigator.mediaDevices.getUserMedia(constraints);
//
//       // ✅ 로컬 스트림 상세 정보
//       print('✅ 로컬 오디오 스트림 초기화 완료');
//       print('   스트림 ID: ${_localStream!.id}');
//       final audioTracks = _localStream!.getAudioTracks();
//       print('   오디오 트랙 수: ${audioTracks.length}');
//       for (var track in audioTracks) {
//         print('   - ${track.label}: enabled=${track.enabled}');
//       }
//       return _localStream;
//     } catch (e) {
//       print('❌ 로컬 스트림 초기화 실패: $e');
//       return null;
//     }
//   }
//
//   // ========================================
//   // 전체 볼륨 / 마이크 제어
//   // ========================================
//
//   /// 전체 스피커 볼륨 (모든 원격 스트림에 적용)
//   void setMasterVolume(double volume) {
//     _masterVolume = volume.clamp(0.0, 1.0);
//
//     // 모든 원격 스트림에 적용 (개별 볼륨 * 마스터 볼륨)
//     _remoteStreams.forEach((peerId, stream) {
//       final peerVol = _peerVolumes[peerId] ?? 1.0;
//       final isMuted = _peerMuted[peerId] ?? false;
//       _applyVolume(stream, isMuted ? 0.0 : peerVol * _masterVolume);
//     });
//
//     print('🔊 마스터 볼륨: ${(_masterVolume * 100).toInt()}%');
//   }
//
//   /// 마이크 게인 조절
//   void setMicrophoneGain(double gain) {
//     _microphoneGain = gain.clamp(0.0, 2.0);
//
//     if (_localStream != null) {
//       final audioTracks = _localStream!.getAudioTracks();
//       for (var track in audioTracks) {
//         // 게인이 0이면 트랙 비활성화로 처리
//         if (_microphoneGain == 0.0) {
//           track.enabled = false;
//         } else if (!_isMicMuted) {
//           track.enabled = true;
//         }
//       }
//     }
//
//     print('🎤 마이크 게인: ${(_microphoneGain * 100).toInt()}%');
//   }
//
//   /// 음소거 토글
//   void toggleAudio(bool enabled) {
//     _isMicMuted = !enabled;
//
//     if (_localStream != null) {
//       final audioTracks = _localStream!.getAudioTracks();
//       for (var track in audioTracks) {
//         track.enabled = enabled;
//       }
//       print(enabled ? '🔊 음소거 해제' : '🔇 음소거');
//     }
//   }
//
//   // ========================================
//   // 클라이언트별 개별 볼륨 제어
//   // ========================================
//
//   /// 특정 피어의 볼륨 조절
//   void setPeerVolume(String peerId, double volume) {
//     _peerVolumes[peerId] = volume.clamp(0.0, 1.0);
//
//     final stream = _remoteStreams[peerId];
//     if (stream != null) {
//       final isMuted = _peerMuted[peerId] ?? false;
//       final effectiveVolume = isMuted ? 0.0 : volume * _masterVolume;
//       _applyVolume(stream, effectiveVolume);
//     }
//
//     onPeerVolumeChanged?.call(peerId, volume);
//     print('🔊 [$peerId] 개별 볼륨: ${(volume * 100).toInt()}%');
//   }
//
//   /// 특정 피어의 볼륨 가져오기
//   double getPeerVolume(String peerId) {
//     return _peerVolumes[peerId] ?? 1.0;
//   }
//
//   /// 특정 피어 음소거 토글
//   void togglePeerMute(String peerId) {
//     final isMuted = !(_peerMuted[peerId] ?? false);
//     _peerMuted[peerId] = isMuted;
//
//     final stream = _remoteStreams[peerId];
//     if (stream != null) {
//       if (isMuted) {
//         _applyVolume(stream, 0.0);
//       } else {
//         final peerVol = _peerVolumes[peerId] ?? 1.0;
//         _applyVolume(stream, peerVol * _masterVolume);
//       }
//     }
//
//     print(isMuted ? '🔇 [$peerId] 음소거' : '🔊 [$peerId] 음소거 해제');
//   }
//
//   /// 특정 피어가 음소거 상태인지 확인
//   bool isPeerMuted(String peerId) {
//     return _peerMuted[peerId] ?? false;
//   }
//
//   /// 스트림에 볼륨 적용 (내부 헬퍼)
//   void _applyVolume(MediaStream stream, double volume) {
//     final audioTracks = stream.getAudioTracks();
//     for (var track in audioTracks) {
//       if (volume == 0.0) {
//         track.enabled = false;
//       } else {
//         track.enabled = true;
//         // flutter_webrtc의 Helper를 통한 볼륨 조절
//         Helper.setVolume(volume, track);
//       }
//     }
//   }
//
//   // ========================================
//   // 시그널링
//   // ========================================
//
//   // 🔧 시그널링 리스너 설정
//   void _setupSignalingListeners() {
//     socketService.onWebRTCOffer((from, offer) async {
//       print('🔗 [WebRTC] Offer 수신: $from');
//       await _handleOffer(from, offer);
//     });
//
//     socketService.onWebRTCAnswer((from, answer) async {
//       print('🔗 [WebRTC] Answer 수신: $from');
//       await _handleAnswer(from, answer);
//     });
//
//     socketService.onWebRTCIceCandidate((from, candidate) async {
//       print('🧊 [WebRTC] ICE Candidate 수신: $from');
//       await _handleIceCandidate(from, candidate);
//     });
//   }
//
//   // ========================================
//   // 피어 연결
//   // ========================================
//
//   // 🔧 피어 연결 생성
//   Future<RTCPeerConnection?> _createPeerConnection(String peerId) async {
//     try {
//       // ✅ 기존 연결이 있으면 상태 확인
//       if (_peerConnections.containsKey(peerId)) {
//         final existingPc = _peerConnections[peerId]!;
//         final connectionState = await existingPc.getConnectionState();
//         final signalingState = await existingPc.getSignalingState();
//
//         print('⚠️ 기존 피어 연결 존재: $peerId');
//         print('   연결 상태: $connectionState');
//         print('   시그널링 상태: $signalingState');
//
//         // ✅ 연결이 이미 안정적이면 재사용
//         if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
//             signalingState == RTCSignalingState.RTCSignalingStateStable) {
//           print('✅ 기존 연결 재사용: $peerId');
//           return existingPc;
//         }
//
//         // ✅ 연결이 실패/종료된 상태면 제거 후 재생성
//         if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
//             connectionState == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
//             connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
//           print('🔄 기존 연결 종료 후 재생성: $peerId');
//           await existingPc.close();
//           _peerConnections.remove(peerId);
//           _remoteStreams.remove(peerId);
//         } else {
//           // ✅ 연결 중이면 기존 연결 재사용
//           print('✅ 기존 연결 재사용 (연결 중): $peerId');
//           return existingPc;
//         }
//       }
//
//       print('🔗 피어 연결 생성 시작: $peerId');
//
//       final pc = await createPeerConnection(_iceServers);
//
//       // 로컬 스트림 추가
//       if (_localStream != null) {
//         _localStream!.getTracks().forEach((track) {
//           pc.addTrack(track, _localStream!);
//         });
//         print('✅ 로컬 오디오 트랙 추가: $peerId');
//       }else{
//         print('⚠️ 로컬 스트림이 없습니다!');
//       }
//
//       // ICE Candidate 이벤트
//       pc.onIceCandidate = (RTCIceCandidate candidate) {
//         if (candidate != null) {
//
//           print('🧊 [로컬] ICE Candidate 생성: $peerId');
//           print('   candidate: ${candidate.candidate}');
//           print('   sdpMid: ${candidate.sdpMid}');
//           print('   sdpMLineIndex: ${candidate.sdpMLineIndex}');
//
//
//           socketService.sendWebRTCIceCandidate(peerId, {
//             'candidate': candidate.candidate,
//             'sdpMid': candidate.sdpMid,
//             'sdpMLineIndex': candidate.sdpMLineIndex,
//           });
//         }
//       };
//
//       // 연결 상태 변화
//       pc.onConnectionState = (RTCPeerConnectionState state) {
//         print('🔗 연결 상태: $peerId -> $state');
//       };
//
//       // ✅ ICE Gathering 상태
//       pc.onIceGatheringState = (RTCIceGatheringState state) {
//         print('🧊 ICE Gathering 상태: $peerId -> $state');
//       };
//
//       // ✅ 연결 상태 변화
//       pc.onConnectionState = (RTCPeerConnectionState state) {
//         print('🔗 연결 상태: $peerId -> $state');
//
//         if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
//             state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
//             state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
//           print('❌ 연결 종료됨: $peerId');
//           removePeerConnection(peerId);
//         }
//       };
//
//       // ✅ 시그널링 상태
//       pc.onSignalingState = (RTCSignalingState state) {
//         print('📡 시그널링 상태: $peerId -> $state');
//       };
//
//       // 원격 스트림 수신
//       pc.onTrack = (RTCTrackEvent event) {
//         print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//         print('📥 원격 트랙 수신: $peerId');
//         print('   트랙 종류: ${event.track.kind}');
//         print('   트랙 ID: ${event.track.id}');
//         print('   트랙 활성화: ${event.track.enabled}');
//         print('   스트림 수: ${event.streams.length}');
//         print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//         if (event.streams.isNotEmpty) {
//           final remoteStream = event.streams[0];
//           _remoteStreams[peerId] = remoteStream;
//
//           // 개별 볼륨 초기화 (없으면 1.0)
//           _peerVolumes.putIfAbsent(peerId, () => 1.0);
//           _peerMuted.putIfAbsent(peerId, () => false);
//
//           // 현재 설정된 볼륨 적용
//           final peerVol = _peerVolumes[peerId]!;
//           final isMuted = _peerMuted[peerId]!;
//           _applyVolume(remoteStream, isMuted ? 0.0 : peerVol * _masterVolume);
//
//
//           onRemoteStreamAdded?.call(peerId, remoteStream);
//         }
//       };
//
//       _peerConnections[peerId] = pc;
//       print('✅ 피어 연결 객체 생성 완료: $peerId');
//       return pc;
//     } catch (e) {
//       print('❌ 피어 연결 생성 실패: $peerId - $e');
//       return null;
//     }
//   }
//
//   // 🔧 Offer 생성
//   Future<void> createOffer(String peerId) async {
//     try {
//       print('📤 Offer 생성: $peerId');
//
//       // ✅ 기존 연결 확인
//       final existingPc = _peerConnections[peerId];
//       if (existingPc != null) {
//         final signalingState = await existingPc.getSignalingState();
//         print('⚠️ 기존 피어 연결 존재: $peerId');
//         print('   시그널링 상태: $signalingState');
//
//         // ✅ 이미 안정화된 연결이면 Offer 생성 안 함
//         if (signalingState == RTCSignalingState.RTCSignalingStateStable) {
//           print('ℹ️ 이미 연결이 안정화되었습니다 (Offer 생성 건너뜀)');
//           return;
//         }
//
//         // ✅ 이미 Offer를 보낸 상태면 건너뜀
//         if (signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
//           print('ℹ️ 이미 Offer를 보낸 상태입니다 (중복 방지)');
//           return;
//         }
//       }
//
//       final pc = await _createPeerConnection(peerId);
//       if (pc == null) {  print('❌ 피어 연결 생성 실패'); return;}
//
//       // ✅ Offer 제약 조건
//       final offerOptions = {
//         'offerToReceiveAudio': true,
//         'offerToReceiveVideo': false,
//       };
//
//       RTCSessionDescription offer = await pc.createOffer(offerOptions);
//       print('✅ Offer SDP 생성 완료');
//       print('   타입: ${offer.type}');
//       print('   SDP 길이: ${offer.sdp?.length ?? 0} bytes');
//
//       await pc.setLocalDescription(offer);
//       print('✅ Local Description 설정 완료');
//
//       // ✅ 상태 확인
//       final signalingState = await pc.getSignalingState();
//       print('   시그널링 상태: $signalingState');
//
//       socketService.sendWebRTCOffer(peerId, {
//         'type': offer.type,
//         'sdp': offer.sdp,
//       });
//
//       print('✅ Offer 전송 완료: $peerId');
//     } catch (e) {
//       print('❌ Offer 생성 실패: $peerId - $e');
//     }
//   }
//
//   // 🔧 Offer 처리
//   Future<void> _handleOffer(String peerId, dynamic offerData) async {
//     try {
//       print('📥 Offer 처리: $peerId');
//
//       final pc = await _createPeerConnection(peerId);
//       if (pc == null) { print('❌ 피어 연결 생성 실패'); return;}
//
//       final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
//       print('✅ Offer SDP 파싱 완료');
//       await pc.setRemoteDescription(offer);
//       print('✅ Remote Description 설정 완료');
//
//       // ✅ Answer 제약 조건
//       final answerOptions = {
//         'offerToReceiveAudio': true,
//         'offerToReceiveVideo': false,
//       };
//
//       RTCSessionDescription answer = await pc.createAnswer(answerOptions);
//       print('✅ Answer SDP 생성 완료');
//       print('   타입: ${answer.type}');
//       print('   SDP 길이: ${answer.sdp?.length ?? 0} bytes');
//
//       await pc.setLocalDescription(answer);
//       print('✅ Local Description 설정 완료');
//
//       socketService.sendWebRTCAnswer(peerId, {
//         'type': answer.type,
//         'sdp': answer.sdp,
//       });
//
//       print('✅ Answer 전송 완료: $peerId');
//     } catch (e) {
//       print('❌ Offer 처리 실패: $peerId - $e');
//     }
//   }
//
//   // 🔧 Answer 처리
//   Future<void> _handleAnswer(String peerId, dynamic answerData) async {
//     try {
//       print('📥 Answer 처리: $peerId');
//
//       final pc = _peerConnections[peerId];
//       if (pc == null) {
//         print('⚠️ 피어 연결 없음: $peerId');
//         return;
//       }
//
//       // ✅ 현재 시그널링 상태 확인
//       final signalingState = await pc.getSignalingState();
//       print('   현재 시그널링 상태: $signalingState');
//
//       // ✅ have-local-offer 상태가 아니면 건너뛰기
//       if (signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
//         print('⚠️ Answer를 받을 수 있는 상태가 아닙니다');
//         print('   예상 상태: have-local-offer');
//         print('   현재 상태: $signalingState');
//
//         // stable 상태라면 이미 처리됨
//         if (signalingState == RTCSignalingState.RTCSignalingStateStable) {
//           print('ℹ️ 이미 연결이 안정화되었습니다 (무시)');
//         }
//
//         return;
//       }
//
//
//       final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
//       print('✅ Answer SDP 파싱 완료');
//
//       await pc.setRemoteDescription(answer);
//       print('✅ Remote Description 설정 완료');
//
//       // ✅ 설정 후 상태 확인
//       final newState = await pc.getSignalingState();
//       print('   새로운 시그널링 상태: $newState');
//
//
//       print('✅ Answer 처리 완료: $peerId');
//     } catch (e) {
//       print('❌ Answer 처리 실패: $peerId - $e');
//     }
//   }
//
//   // 🔧 ICE Candidate 처리
//   Future<void> _handleIceCandidate(String peerId, dynamic candidateData) async {
//     try {
//       final pc = _peerConnections[peerId];
//       if (pc == null) {
//         print('⚠️ ICE: 피어 연결 없음 - $peerId');
//         return;
//       }
//
//       final candidate = RTCIceCandidate(
//         candidateData['candidate'],
//         candidateData['sdpMid'],
//         candidateData['sdpMLineIndex'],
//       );
//
//       await pc.addCandidate(candidate);
//       print('✅ ICE Candidate 추가: $peerId');
//     } catch (e) {
//       print('❌ ICE Candidate 실패: $peerId - $e');
//     }
//   }
//
//   // 🔧 기존 참여자들과 연결
//   Future<void> connectToExistingPeers(List<dynamic> existingPeers) async {
//     print('🔗 기존 참여자 연결: ${existingPeers.length}명');
//
//     // ✅ 전체 데이터 구조 확인
//     print('📦 받은 데이터: $existingPeers');
//
//     for (var peer in existingPeers) {
//
//       // ✅ 각 peer 객체 상세 출력
//       print('👤 Peer: $peer');
//       try{
//         final peerId = peer['userId'] as String;
//         await createOffer(peerId);
//         print('   ✅ Offer 생성 완료');
//         await Future.delayed(const Duration(milliseconds: 500));
//       }catch(e){
//         print('   ❌ 연결 실패: $e');
//       }
//
//     }
//   }
//
//   // 🔧 피어 연결 제거
//   void removePeerConnection(String peerId) {
//     _peerConnections[peerId]?.close();
//     _peerConnections.remove(peerId);
//     _remoteStreams.remove(peerId);
//     _peerVolumes.remove(peerId);
//     _peerMuted.remove(peerId);
//     onRemoteStreamRemoved?.call(peerId);
//     print('🗑️ 피어 연결 제거: $peerId');
//   }
//
//   // 🔧 원격 스트림 가져오기
//   MediaStream? getRemoteStream(String peerId) => _remoteStreams[peerId];
//   Map<String, MediaStream> get remoteStreams => _remoteStreams;
//
//   // 🔧 정리
//   Future<void> dispose() async {
//     print('🧹 WebRTC 정리 시작');
//
//     for (var pc in _peerConnections.values) {
//       await pc.close();
//     }
//     _peerConnections.clear();
//
//     if (_localStream != null) {
//       _localStream!.getTracks().forEach((track) => track.stop());
//       await _localStream!.dispose();
//       _localStream = null;
//     }
//
//     _remoteStreams.clear();
//     _peerVolumes.clear();
//     _peerMuted.clear();
//
//     socketService.offWebRTCOffer();
//     socketService.offWebRTCAnswer();
//     socketService.offWebRTCIceCandidate();
//
//     print('✅ WebRTC 정리 완료');
//   }
// }
//

