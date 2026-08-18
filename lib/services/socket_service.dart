import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quepilot_client_01/db/hive_service.dart';
import 'package:quepilot_client_01/db/model/hive_key_model.dart';
import 'package:quepilot_client_01/models/message_model.dart';
import 'package:quepilot_client_01/models/service_model.dart';
import 'package:quepilot_client_01/models/timeline_model.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'discovery_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();

  // IO.Socket? _mainSocket;
  // IO.Socket? _projectSocket;

  IO.Socket? _socket;

  String serverUrl = 'http://192.168.0.7:8888';
  String socketIoPath = '/api';
  String? currentProjectId;
  String? currentRoomId;
  // String? currentUsername;
  String _type = 'client';

  int reconnectionDelay = 3000;
  int reconnectionDelayMax = 6000;
  int reconnectionAttempts = 3;

  String? _sessionCookie; //로그인 세션
  User _user = User(id: '', login_id: '', name: ''); // 로그인된 사용자 정보

  bool _isDiscovering = false;
  StreamSubscription? _discoverySub;

  final hiveService = HiveService();

  bool get isLoggedIn => _sessionCookie != null && _user.id.isNotEmpty;  // 로그인 상태
  User get loggedInUser => _user;

  bool get isConnected => _socket != null && _socket!.connected;
  bool get isMainConnected => isConnected && currentProjectId == null;
  bool get isProjectConnected => isConnected && currentProjectId != null;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  // 메인 네임스페이스에서 항상 필요한 리스너들
  // final Map<String, Function> _mainListeners = {};

  // 프로젝트 네임스페이스에서 필요한 리스너들
  // final Map<String, Function> _projectListeners = {};

  // -- 연결 상태 --
  final _connectionState = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionState.stream;

  // -- 1:1 직접 통화 --
  final _incomingDirectCall = StreamController<IncomingDirectCallEvent>.broadcast();
  final _directCallCancelled = StreamController<DirectCallCancelledEvent>.broadcast();
  final _directCallEnded = StreamController<DirectCallEndedEvent>.broadcast();

  Stream<IncomingDirectCallEvent> get incomingDirectCall => _incomingDirectCall.stream;
  Stream<DirectCallCancelledEvent> get directCallCancelled => _directCallCancelled.stream;
  Stream<DirectCallEndedEvent> get directCallEnded => _directCallEnded.stream;

  // -- Direct WebRTC --
  final _directWebRTCOffer = StreamController<DirectWebRTCEvent>.broadcast();
  final _directWebRTCAnswer = StreamController<DirectWebRTCEvent>.broadcast();
  final _directWebRTCIce = StreamController<DirectWebRTCEvent>.broadcast();

  Stream<DirectWebRTCEvent> get directWebRTCOffer => _directWebRTCOffer.stream;
  Stream<DirectWebRTCEvent> get directWebRTCAnswer => _directWebRTCAnswer.stream;
  Stream<DirectWebRTCEvent> get directWebRTCIce => _directWebRTCIce.stream;

  // -- 개인 메시지 --
  final _receivePersonalMessage = StreamController<MessageData>.broadcast();
  Stream<MessageData> get receivePersonalMessage => _receivePersonalMessage.stream;

  // -- 유저 입퇴장 --
  final _userJoined = StreamController<RoomUserEvent>.broadcast();
  final _userLeft = StreamController<RoomUserEvent>.broadcast();

  Stream<RoomUserEvent> get userJoined => _userJoined.stream;
  Stream<RoomUserEvent> get userLeft => _userLeft.stream;

  // -- 방 메시지 --
  final _receiveMessage = StreamController<MessageData>.broadcast();
  final _receiveMessageProjectWhole = StreamController<MessageData>.broadcast();

  Stream<MessageData> get receiveMessage => _receiveMessage.stream;
  Stream<MessageData> get receiveMessageProjectWhole => _receiveMessageProjectWhole.stream;

  // -- 방 CRUD --
  final _roomCreated = StreamController<RoomCreatedEvent>.broadcast();
  final _roomUpdated = StreamController<RoomUpdatedEvent>.broadcast();
  final _roomDeleted = StreamController<RoomDeletedEvent>.broadcast();

  Stream<RoomCreatedEvent> get roomCreated => _roomCreated.stream;
  Stream<RoomUpdatedEvent> get roomUpdated => _roomUpdated.stream;
  Stream<RoomDeletedEvent> get roomDeleted => _roomDeleted.stream;

  // -- 방 통화 --
  final _callParticipantsUpdated = StreamController<CallParticipantsEvent>.broadcast();
  final _userJoinedCall = StreamController<CallUserEvent>.broadcast();
  final _userLeftCall = StreamController<CallUserEvent>.broadcast();
  final _peerMuteChanged = StreamController<PeerMuteEvent>.broadcast();

  Stream<CallParticipantsEvent> get callParticipantsUpdated => _callParticipantsUpdated.stream;
  Stream<CallUserEvent> get userJoinedCall => _userJoinedCall.stream;
  Stream<CallUserEvent> get userLeftCall => _userLeftCall.stream;
  Stream<PeerMuteEvent> get peerMuteChanged => _peerMuteChanged.stream;

  // -- Room WebRTC --
  final _webRTCOffer = StreamController<RoomWebRTCEvent>.broadcast();
  final _webRTCAnswer = StreamController<RoomWebRTCEvent>.broadcast();
  final _webRTCIce = StreamController<RoomWebRTCEvent>.broadcast();

  Stream<RoomWebRTCEvent> get webRTCOffer => _webRTCOffer.stream;
  Stream<RoomWebRTCEvent> get webRTCAnswer => _webRTCAnswer.stream;
  Stream<RoomWebRTCEvent> get webRTCIce => _webRTCIce.stream;

  // -- 트랙 --
  final _trackAdded = StreamController<TrackEvent>.broadcast();
  final _trackUpdated = StreamController<TrackEvent>.broadcast();
  final _trackDeleted = StreamController<TrackDeletedEvent>.broadcast();

  Stream<TrackEvent> get trackAdded => _trackAdded.stream;
  Stream<TrackEvent> get trackUpdated => _trackUpdated.stream;
  Stream<TrackDeletedEvent> get trackDeleted => _trackDeleted.stream;

  // -- 권한 --
  final _permissionUpdated = StreamController<PermissionUpdatedEvent>.broadcast();
  Stream<PermissionUpdatedEvent> get permissionUpdated => _permissionUpdated.stream;

  // -- 재생 제어 --
  final _onPlay = StreamController<PlaybackEvent>.broadcast();
  final _onPause = StreamController<PlaybackEvent>.broadcast();
  final _onStop = StreamController<void>.broadcast();
  final _timelineHeartbeat = StreamController<PlaybackEvent>.broadcast();

  Stream<PlaybackEvent> get onPlayStream => _onPlay.stream;
  Stream<PlaybackEvent> get onPauseStream => _onPause.stream;
  Stream<void> get onStopStream => _onStop.stream;
  Stream<PlaybackEvent> get timelineHeartbeat => _timelineHeartbeat.stream;


  /// 메인 + 프로젝트 공통으로 항상 필요한 이벤트
  void _bindAlwaysListeners() {
    if (_socket == null) return;

    // 1:1 통화 수신
    _socket!.on('incoming-direct-call', (data) {
      _incomingDirectCall.add(IncomingDirectCallEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('direct-call-cancelled', (data) {
      _directCallCancelled.add(DirectCallCancelledEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('direct-call-ended', (data) {
      _directCallEnded.add(DirectCallEndedEvent.fromJson(Map<String, dynamic>.from(data)));
    });

    // Direct WebRTC
    _socket!.on('direct-webrtc-offer', (data) {
      _directWebRTCOffer.add(DirectWebRTCEvent.fromJson(Map<String, dynamic>.from(data), 'offer'));
    });
    _socket!.on('direct-webrtc-answer', (data) {
      _directWebRTCAnswer.add(DirectWebRTCEvent.fromJson(Map<String, dynamic>.from(data), 'answer'));
    });
    _socket!.on('direct-webrtc-ice-candidate', (data) {
      _directWebRTCIce.add(DirectWebRTCEvent.fromJson(Map<String, dynamic>.from(data), 'candidate'));
    });

    // 개인 메시지
    _socket!.on('receive-personal-message', (data) {
      _receivePersonalMessage.add(MessageData.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void _bindProjectListeners() {
    if (_socket == null) return;

    // 유저 입퇴장
    _socket!.on('user-joined', (data) {
      _userJoined.add(RoomUserEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('user-left', (data) {
      _userLeft.add(RoomUserEvent.fromJson(Map<String, dynamic>.from(data)));
    });

    // 방 메시지
    _socket!.on('receive-message', (data) {
      _receiveMessage.add(MessageData.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('receive-message-project-whole', (data) {
      _receiveMessageProjectWhole.add(MessageData.fromJson(Map<String, dynamic>.from(data)));
    });

    // 방 CRUD
    _socket!.on('room-created', (data) {
      _roomCreated.add(RoomCreatedEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('room-updated', (data) {
      _roomUpdated.add(RoomUpdatedEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('room-deleted', (data) {
      _roomDeleted.add(RoomDeletedEvent.fromJson(Map<String, dynamic>.from(data)));
    });

    // 방 통화
    _socket!.on('call-participants-updated', (data) {
      _callParticipantsUpdated.add(CallParticipantsEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('user-joined-call', (data) {
      _userJoinedCall.add(CallUserEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('user-left-call', (data) {
      _userLeftCall.add(CallUserEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('peer-mute-changed', (data) {
      _peerMuteChanged.add(PeerMuteEvent.fromJson(Map<String, dynamic>.from(data)));
    });

    // Room WebRTC
    _socket!.on('webrtc-offer', (data) {
      _webRTCOffer.add(RoomWebRTCEvent.fromJson(Map<String, dynamic>.from(data), 'offer'));
    });
    _socket!.on('webrtc-answer', (data) {
      _webRTCAnswer.add(RoomWebRTCEvent.fromJson(Map<String, dynamic>.from(data), 'answer'));
    });
    _socket!.on('webrtc-ice-candidate', (data) {
      _webRTCIce.add(RoomWebRTCEvent.fromJson(Map<String, dynamic>.from(data), 'candidate'));
    });

    // 트랙
    _socket!.on('track-added', (data) {
      _trackAdded.add(TrackEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('track-updated', (data) {
      _trackUpdated.add(TrackEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('track-deleted', (data) {
      _trackDeleted.add(TrackDeletedEvent.fromJson(Map<String, dynamic>.from(data)));
    });

    // 권한
    _socket!.on('permissions-updated', (data) {
      _permissionUpdated.add(PermissionUpdatedEvent.fromJson(Map<String, dynamic>.from(data)));
    });

    // 재생 제어
    _socket!.on('project-play', (data) {
      _onPlay.add(PlaybackEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('project-pause', (data) {
      _onPause.add(PlaybackEvent.fromJson(Map<String, dynamic>.from(data)));
    });
    _socket!.on('project-stop', (data) {
      _onStop.add(null);
    });
    _socket!.on('timeline-auto-stopped', (data) {
      _onStop.add(null);
    });
    _socket!.on('timeline-heartbeat', (data) {
      _timelineHeartbeat.add(PlaybackEvent.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  // ========================================
  // HTTP 로그인 / 로그아웃
  // ========================================

  /// POST /login → 세션 쿠키 획득
  Future<void> login(String login_id, String password, Function(bool success, User? user, String? sessionCookie) callback) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login_id': login_id,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {

        // ✅ set-cookie 헤더에서 세션 쿠키 추출
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          _sessionCookie = _extractSessionCookie(setCookie);
        }

        _user = User.fromJson(data['user']);
        // SharedPreferences에 저장

        print('✅ 로그인 성공: ${_user.login_id}');
        print('🍪 세션 쿠키: $_sessionCookie');

        callback(true,_user, _sessionCookie);
      } else {
        print('❌ 로그인 실패: ${data['message']}');
        callback(false, null, null);
      }
    } catch (e,stackTrace) {
      print('❌ 로그인 오류: $e');
      print('$stackTrace');
      callback(false,null, null);
    }
  }

  /// POST /logout
  Future<bool> logout() async {
    try {
      if (_sessionCookie == null) return false;

      final response = await http.post(
        Uri.parse('$serverUrl/logout'),
        headers: {
          'Content-Type': 'application/json',
          'cookie': _sessionCookie!,
        },
      );

      // 소켓 연결 해제
      await socketOut();

      // 세션 정보 클리어
      _sessionCookie = null;
      _user = User(id: '', login_id: '', name: '');
      currentProjectId = null;

      print('✅ 로그아웃 완료');
      return true;
    } catch (e) {
      print('❌ 로그아웃 오류: $e');
      return false;
    }
  }

  /// GET /session → 세션 유효성 확인
  Future<void> checkSession(String sessionCookie, Function(bool, User) callback) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/session'),
        headers: {
          'Content-Type': 'application/json',
          'cookie': sessionCookie,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _user = User.fromJson(data['user']);
        _sessionCookie = sessionCookie;
        print('✅ 세션 유효: ${_user.name} ');
        callback(true, _user);
      } else {
        print('❌ 세션 만료');
        _sessionCookie = null;
        _user = User(id: '', login_id: '', name: '');
        callback(false, User(id: '', login_id: '', name: ''));
      }
    } catch (e, stackTrack) {
      print('❌ 세션 확인 오류: $e');
      print('❌ 세션 확인 오류: $stackTrack');
      callback(false, User(id: '', login_id: '', name: ''));
    }
  }

  // ========================================
  // set-cookie 파싱
  // ========================================

  /// "localSessionId=s%3Aabc123.sig; Path=/; HttpOnly" → "localSessionId=s%3Aabc123.sig"
  String? _extractSessionCookie(String setCookieHeader) {

    // 여러 쿠키가 콤마로 구분될 수 있음
    final cookies = setCookieHeader.split(',');

    for (final cookie in cookies) {
      final trimmed = cookie.trim();
      if (trimmed.startsWith('localSessionId=')) {
        // 첫 번째 세미콜론까지만 추출 (Path, HttpOnly 등 제거)
        final value = trimmed.split(';')[0].trim();
        return value;
      }
    }

    // localSessionId를 못 찾으면 첫 번째 쿠키의 key=value만
    final firstCookie = setCookieHeader.split(';')[0].trim();
    return firstCookie;
  }

  /// GET /projects → 프로젝트 목록 획득
  // Future<void> getProjectList(Function(List<Map<String, dynamic>>) callback) async {
  //   try {
  //
  //     if(_sessionCookie == null){
  //       print("세션쿠키 없음");
  //       callback([]);
  //     }
  //
  //     final response = await http.get(
  //       Uri.parse('$serverUrl/projects'),
  //       headers: {'cookie':_sessionCookie!},
  //     );
  //
  //     final data = jsonDecode(response.body);
  //
  //     if (response.statusCode == 200 && data['success'] == true) {
  //
  //       data['projects'] == null ? callback([]):
  //       callback(List<Map<String, dynamic>>.from(data['projects']));
  //
  //     } else {
  //       print('❌ 프로젝트 리스트 불러오기 실패');
  //       callback([]);
  //     }
  //
  //   } catch (e) {
  //     print('❌ 프로젝트 리스트 불러오기 실패: $e');
  //     callback([]);
  //   }
  // }

  /// 서버를 자동으로 찾아서 연결
  Future<bool> autoConnect() async {
    if (_isDiscovering) return false;
    _isDiscovering = true;

    print('🔍 서버 자동 탐색 시작...');

    try {
      final result = await DiscoveryService.discoverServer(
        timeout: const Duration(seconds: 5),
      );

      if (result != null) {
        print('✅ 서버 발견: ${result.url}');
        serverUrl = result.url;
        socketIoPath = result.socketPath;

        // Hive에 저장 (다음 실행 시 빠른 연결용)
        hiveService.optionSaveString(HiveKeyModel().lastURL, result.url);
        hiveService.optionSaveString(HiveKeyModel().lastIP, result.ip);

        // connectToMainServer(null,null,null);
        _isDiscovering = false;
        return true;
      }

      print('❌ 서버를 찾지 못함');
      _isDiscovering = false;
      return false;
    } catch (e) {
      print('❌ 자동 연결 오류: $e');
      _isDiscovering = false;
      return false;
    }
  }

  /// 서버를 찾을 때까지 계속 시도 (백그라운드)
  void startAutoDiscovery({
    Function(String serverUrl)? onFound,
    Function()? onSearching,
  }) {
    _discoverySub?.cancel();

    _discoverySub = DiscoveryService.discoverServerStream(
      searchTimeout: const Duration(seconds: 5),
      retryInterval: const Duration(seconds: 10),
    ).listen((result) {
      // 이미 같은 서버에 연결되어 있으면 무시
      if (isMainConnected && serverUrl == result.url) return;

      print('✅ 서버 발견: ${result.url}');
      // serverUrl = result.url;
      serverUrl = "http://192.168.50.126:8888";
      socketIoPath = result.socketPath;
      hiveService.optionSaveString(HiveKeyModel().lastURL, result.url);

      onFound?.call(result.url);

      // 연결 안 되어 있으면 자동 연결
      if (!isMainConnected) {
        connectToMainServer(null,null,null);
      }
    });
  }

  void stopAutoDiscovery() {
    _discoverySub?.cancel();
    _discoverySub = null;
  }

  // 메인 서버에 연결
  void connectToMainServer(Function()? onConnected, Function()? onDisconnected , Function(String error)? onError) {

    //이미 메인 서버에 연결되어 있으면 스킵
    if(isMainConnected){
      return;
    }

    socketOut();

    currentProjectId = null;

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(reconnectionDelay)
          .setReconnectionDelayMax(reconnectionDelayMax)
          .setReconnectionAttempts(reconnectionAttempts)
          .enableForceNew()
          .setPath(socketIoPath)
          .setAuth({
            'type':_type,
          })
          .setExtraHeaders({
            'cookie':_sessionCookie!,
          })
          .build());

    _bindAlwaysListeners();

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('메인 서버에 연결됨');
      }

      _connectionState.add(true);
      onConnected?.call();
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('메인 서버 연결 해제됨');
      }
      _connectionState.add(false);
      onDisconnected?.call();
    });

    _socket!.onError((error) {
      if (kDebugMode) {
        print('연결 오류: $error');
      }

      onError?.call(error.toString());
    });
  }

  // 프로젝트별 네임스페이스에 연결
  Future<void> connectToProject(String projectId, Function()? onConnected , Function(String error)? onError) async {
    currentProjectId = projectId;

    //소켓  null 확인후 진행
    await socketOut();

    // 빠른 해체후 연결은 연속 접속의 원인이 됨
    await Future.delayed(const Duration(seconds: 1)).then(((_){}));

    currentProjectId = projectId;

    _socket = IO.io(
        '$serverUrl/$projectId',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(reconnectionDelay)
            .setReconnectionDelayMax(reconnectionDelayMax)
            .setReconnectionAttempts(reconnectionAttempts)
            .enableForceNew()
            .setPath(socketIoPath)
            .setAuth({
              'type':_type,
              'userId': _user.id,
            })
            .setExtraHeaders({
              'cookie':_sessionCookie!,
            })
            .build());

    _bindAlwaysListeners();
    _bindProjectListeners();

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('프로젝트 $projectId에 연결됨');
      }
      _connectionState.add(true);
      onConnected?.call();
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('프로젝트 $projectId 연결 해제됨');
      }
      _connectionState.add(false);
    });

    _socket!.onError((error) {
      if (kDebugMode) {
        print('연결 오류: $error');
      }

      onError?.call(error.toString());
    });


  }


  // 프로젝트별 네임스페이스에 연결해제
  Future<void> socketOut() async {

    if(_socket != null){
      _socket!.clearListeners();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  // 메인 네임스페이스용 리스너 등록 (재연결 시 자동복원)

  // 메인 리스너 해제

  // 프로젝트 네임스페이스용 리스너 등록

  // 프로젝트 리스너 해제


  // 프로젝트 생성
  // void login(String name,String password, Function(bool,Map<String,dynamic>) callback) {
  //   _socket!.emitWithAck('login', {
  //     'name': name,
  //     'password':password,
  //   }, ack: (data) {
  //     callback(data['success'] ?? false,data['info'] ?? {});
  //   });
  // }

  // 프로젝트 목록 요청
  void getProjectList(Function(List<Map<String, dynamic>>) callback) {
    _socket!.emitWithAck('project-list', {}, ack: (data) {
      if (data['success']) {
        //print(data['projects'].runtimeType);
        //print(data['projects']);
        data['projects'] == null ? callback([]):
        callback(List<Map<String, dynamic>>.from(data['projects']));
        //callback(data['projects']);
      }
    });
  }

  // 방에 입장
  void joinRoom(String roomId, Function(bool, List<Map<String, dynamic>>) callback) {
    currentRoomId = roomId;
    // currentUsername = userName;

    _socket!.emitWithAck('join-room', {
      'roomId': roomId,
      'userId': _user.id,
      'userName': _user.name
    }, ack: (data) {
      if (data['success']) {
        List<Map<String, dynamic>> members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        callback(true, members);
      } else {
        callback(false, []);
      }
    });
  }

  // 방 목록 조회
  void getAllRooms(Function(List<Map<String, dynamic>>) callback) {
    _socket!.emitWithAck('room-list', {}, ack: (data) {
      if (data['success']) {
        callback(List<Map<String, dynamic>>.from(data['rooms']));
      }
    });
  }

  // 방 정보 조회
  void getRoomInfo(String roomId , Function(bool,Map<String, dynamic>?) callback) {
    _socket!.emitWithAck('get-room-info', {
      'roomId': roomId,
      'userId': _user.id,
    }, ack: (data) {
      if (data['success']) {
        callback(data['myAuth'],data['room']);
      } else {
        callback(false,null);
      }
    });
  }

  // 방 타임라인 조회
  void getTimeLine(String roomId, Function(Map<String, dynamic>?) callback) {
    _socket!.emitWithAck('get-timeline', {
      'roomId': roomId
    }, ack: (data) {
      if (data['success']) {
        callback(data['timeline']);
      } else {
        callback(null);
      }
    });
  }

  // 방 메시지 로드
  void getRoomMessages(String roomId, Function(List<Map<String,dynamic>>) callback) {
    _socket!.emitWithAck('get-messages-room', {
      'roomId' : roomId,
    }, ack: (data) {
      if(data['success']){
        final messages = List<Map<String,dynamic>>.from(data['messages'] ?? []);
        callback(messages);
      }else{
        callback([]);
      }
    });
  }

  // 개인 메시지 로드
  void getPersonalMessages(String userId, Function(List<Map<String,dynamic>>) callback) {
    _socket!.emitWithAck('get-messages-personal', {
      'userId' : userId,
    }, ack: (data) {
      if(data['success']){
        final messages = List<Map<String,dynamic>>.from(data['messages'] ?? []);
        callback(messages);
      }else{
        callback([]);
      }
    });
  }

  // 메시지 전송
  void sendMessage(String message) {
    _socket!.emit('send-message', {
      'message': message
    });
  }

  // 메시지 전송
  void sendPersonalMessage(String userId,String message,Function(bool, MessageData) callback) {
    _socket!.emitWithAck('send-personal-message', {
      'userId': userId,
      'fromUsername': _user.name,
      'message': message,
    }, ack: (data) {
      callback(data['success'], MessageData.fromJson(data['messageData']));
    });
  }




// 🔧 진행 중인 통화 확인
  void getActiveCall(String roomId, Function(bool, dynamic) callback) {
    _socket?.emitWithAck('get-active-call', {
      'roomId': roomId,
    }, ack: (response) {
      if (response != null && response['success'] == true) {
        print('✅ 진행 중인 통화 조회 성공');
        callback(true, response);
      } else {
        print('⚠️ 진행 중인 통화 없음');
        callback(false, response);
      }
    });
  }

  // 🔧 통화 참여
  void joinRoomCall(String roomId,bool isMuted, Function(bool, dynamic) callback) {
    _socket?.emitWithAck('join-room-call', {
      'roomId': roomId,
      'isMuted': isMuted,
    }, ack: (response) {
      if (response != null && response['success'] == true) {
        callback(true, response);
      } else {
        callback(false, response);
      }
    });
  }

  // 🔧 통화 나가기
  void leaveRoomCall(String roomId,Function(bool, dynamic) callback) {
    _socket?.emitWithAck('leave-room-call', {
      'roomId': roomId,
    }, ack: (response) {
      if (response != null && response['success'] == true) {
        callback(true, response);
      } else {
        callback(false, response);
      }
    });
  }

  // 🔧 음소거 토글
  void toggleMute(String roomId, bool isMuted) {
    _socket?.emit('toggle-mute', {
      'roomId': roomId,
      'isMuted': isMuted,
    });
    print('🔇 음소거 상태 전송: $isMuted');
  }

  // 🔧 통화 참여자 업데이트 이벤트
  // void onCallParticipantsUpdated(Function(List<Map<String, dynamic>>, int) callback) {
  //   _socket?.on('call-participants-updated', (data) {
  //     final participants = List<Map<String, dynamic>>.from(data['participants'] ?? []);
  //     final total = data['totalParticipants'] as int? ?? 0;
  //     callback(participants, total);
  //   });
  // }
  //
  // void offCallParticipantsUpdated() {
  //   _socket?.off('call-participants-updated');
  // }
  //
  // // 🔧 사용자 통화 참여 이벤트
  // void onUserJoinedCall(Function(String userId, String username) callback) {
  //   _socket?.on('user-joined-call', (data) {
  //     callback(data['userId'], data['username']);
  //   });
  // }
  //
  // void offUserJoinedCall() {
  //   _socket?.off('user-joined-call');
  // }
  //
  // // 🔧 사용자 통화 나감 이벤트
  // void onUserLeftCall(Function(String userId, String username) callback) {
  //   _socket?.on('user-left-call', (data) {
  //     callback(data['userId'], data['username']);
  //   });
  // }
  //
  // void offUserLeftCall() {
  //   _socket?.off('user-left-call');
  // }
  //
  // // 🔧 피어 음소거 상태 변경
  // void onPeerMuteChanged(Function(String userId, bool isMuted) callback) {
  //   _socket?.on('peer-mute-changed', (data) {
  //     callback(data['userId'], data['isMuted']);
  //   });
  // }
  //
  // void offPeerMuteChanged() {
  //   _socket?.off('peer-mute-changed');
  // }
  //
  //
  // // 🔧 WebRTC Signaling: ICE Candidate
  // void onWebRTCIceCandidate(Function(String from, dynamic candidate) callback) {
  //   _socket?.on('webrtc-ice-candidate', (data) {
  //     callback(data['from'], data['candidate']);
  //   });
  // }
  //
  // void offWebRTCIceCandidate() {
  //   _socket?.off('webrtc-ice-candidate');
  // }

  // 🔧 WebRTC Offer 전송
  void sendWebRTCOffer(String to, dynamic offer) {
    _socket?.emit('webrtc-offer', {'to': to, 'offer': offer});
    print('📤 WebRTC Offer 전송: $to');
  }

  // 🔧 WebRTC Answer 전송
  void sendWebRTCAnswer(String to, dynamic answer) {
    _socket?.emit('webrtc-answer', {'to': to, 'answer': answer});
    print('📤 WebRTC Answer 전송: $to');
  }

  // 🔧 WebRTC ICE Candidate 전송
  void sendWebRTCIceCandidate(String to, dynamic candidate) {
    _socket?.emit('webrtc-ice-candidate', {'to': to, 'candidate': candidate});
    print('📤 ICE Candidate 전송: $to');
  }

  // 개인통화

// 수신: 전화가 왔을 때
//   void onIncomingDirectCall(Function(String callId, String callerId, String callerName) callback) {
//     _socket?.on('incoming-direct-call', (data) {
//       _incomingDirectCall.add(Map<String,dynamic>.from(data));
//       callback(data['callId'], data['callerId'], data['callerName']);
//     });
//   }
//
//   void offIncomingDirectCall(){
//     _socket?.off('incoming-direct-call');
//   }

// 수락
  void acceptDirectCall(String callId, String receiverName, Function(bool) callback) {
    _socket?.emitWithAck('accept-direct-call', {
      'callId': callId,
      'receiverName': receiverName,
    }, ack: (response) {
      callback(response['success'] ?? false);
    });
  }

// 거절
  void rejectDirectCall(String callId, Function(bool) callback) {
    _socket?.emitWithAck('reject-direct-call', {
      'callId': callId,
    }, ack: (response) {
      callback(response['success'] ?? false);
    });
  }

// 종료
  void endDirectCall(String callId, Function(bool)? callback) {
    _socket?.emitWithAck('end-direct-call', {
      'callId': callId,
    }, ack: (response) {
      callback?.call(response['success'] ?? false);
    });
  }



// ★ 개인 통화 WebRTC 시그널링 (메인 소켓)
  void sendDirectWebRTCOffer(String callId, String to, dynamic offer) {
    _socket?.emit('direct-webrtc-offer', {'callId': callId, 'to': to, 'offer': offer});
  }

  void sendDirectWebRTCAnswer(String callId, String to, dynamic answer) {
    _socket?.emit('direct-webrtc-answer', {'callId': callId, 'to': to, 'answer': answer});
  }

  void sendDirectWebRTCIceCandidate(String callId, String to, dynamic candidate) {
    _socket?.emit('direct-webrtc-ice-candidate', {'callId': callId, 'to': to, 'candidate': candidate});
  }





  // 방 나가기
  void leaveRoom() {
    _socket!.emit('leave-room', {});
    currentRoomId = null;
  }

  // 타임라인 업데이트
  void addTrack(String projectId,String name, String roomId, List<Cue> cues, Function(bool, Map<String,dynamic>?) callback){
    _socket!.emitWithAck('create-track', {
      'projectId':projectId,
      'name':name,
      'roomId':roomId,
      'cues':cues
    }, ack:(data){
      if(data['success'] == true){
        callback(true,data['track']);
      }else{
        callback(false,null);
      }
    });

  }

  // 타임라인 업데이트
  void updateTrack(String projectId,String trackId, String name, String roomId, List<Cue> cues, Function(bool, Map<String,dynamic>?) callback){
    print("updateTracks");
    _socket!.emitWithAck('update-track', {
      'projectId':projectId,
      'trackId':trackId,
      'name':name,
      'roomId':roomId,
      'cues':cues
    }, ack:(data){
      if(data['success'] == true){
        callback(true,data['track']);
      }else{
        callback(false,null);
      }
    });

  }

  //타임라인 삭제
  void deleteTrack(String projectId, String roomId, String trackId, Function(bool, String?) callback) {
    print("deleteTracks");
    _socket!.emitWithAck('delete-track',{
      'projectId':projectId,
      'roomId':roomId,
      'trackId':trackId
    }, ack: (data){
      if(data['success'] == true){
        callback(true,data['trackId']);
      }else{
        callback(false,null);
      }
    });
  }

  void dispose() {
    socketOut();

    stopAutoDiscovery();

    _connectionState.close();

    // 1:1 통화
    _incomingDirectCall.close();
    _directCallCancelled.close();
    _directCallEnded.close();
    _directWebRTCOffer.close();
    _directWebRTCAnswer.close();
    _directWebRTCIce.close();

    // 개인 메시지
    _receivePersonalMessage.close();

    // 유저 입퇴장
    _userJoined.close();
    _userLeft.close();

    // 방 메시지
    _receiveMessage.close();
    _receiveMessageProjectWhole.close();

    // 방 CRUD
    _roomCreated.close();
    _roomUpdated.close();
    _roomDeleted.close();

    // 방 통화
    _callParticipantsUpdated.close();
    _userJoinedCall.close();
    _userLeftCall.close();
    _peerMuteChanged.close();

    // Room WebRTC
    _webRTCOffer.close();
    _webRTCAnswer.close();
    _webRTCIce.close();

    // 트랙
    _trackAdded.close();
    _trackUpdated.close();
    _trackDeleted.close();

    // 권한
    _permissionUpdated.close();

    // 재생
    _onPlay.close();
    _onPause.close();
    _onStop.close();
    _timelineHeartbeat.close();
  }
}

