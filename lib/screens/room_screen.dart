import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quepilot_client_01/models/message_model.dart';
import 'package:quepilot_client_01/models/service_model.dart';
import 'package:quepilot_client_01/services/web_rtc_service.dart';
import '../services/socket_service.dart';
import '../db/hive_service.dart';
import '../utils/colorUtils.dart';

import '../controllers/timeline_controller.dart';
import '../models/timeline_model.dart';
import '../widgets/timeline_widget.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final List<Map<String, dynamic>> members;

  const RoomScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.members,
  }) : super(key: key);

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  final socketService = SocketService();
  final hiveService = HiveService();
  final List<StreamSubscription> _subs = [];
  List<MessageData> messages = [];
  bool myAuth = false;
  late String _roomName;
  final TextEditingController messageController = TextEditingController();
  final timelineController = TimelineController();

  late WebRTCService webRTCService;
  List<CallParticipant> _callParticipants = [];
  int _totalCallParticipants = 0;
  bool _isDisposed = false;
  bool _isInCall = false;
  bool _isMuted = false;

  // ✅ 오디오 설정
  double _speakerVolume = 1.0;
  double _microphoneGain = 1.0;

  // 코멘트 오프셋 (메모리 캐시)
  double _commentOffset = 2.0;

  late AnimationController _sidePanelController;
  late Animation<Offset> _sidePanelAnimation;
  bool _isSidePanelOpen = false;

  bool _isCommentPanelExpanded = false;
  final double _commentPanelMinHeight = 40.0;
  final double _commentPanelMaxHeight = 100.0;

  double _callButtonRight = 16;
  double _callButtonBottom = 100;

  final double _sidePanelWidth = 300.0;

  // ✅ 팝업 위치용 GlobalKey
  final GlobalKey _audioSettingsKey = GlobalKey();
  final GlobalKey _peerVolumeKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _roomName = widget.roomName;
    webRTCService = WebRTCService(socketService);
    _commentOffset = hiveService.readCommentOffset();

    final callPos = hiveService.readCallButtonPos();
    _callButtonRight = callPos[0];
    _callButtonBottom = callPos[1];

    _sidePanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sidePanelAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sidePanelController,
      curve: Curves.easeInOut,
    ));

    _setupEventListeners();
    _loadRoomInfo();
    _loadTimeLine();
    _loadHistoryMessages();
    _checkActiveCall();
  }

  void _setupEventListeners() {

    _subs.add(socketService.userJoined.listen((data) {
      if (mounted) {
        setState(() {
          if (!widget.members.any((member) => member['userId'] == data.userId)) {
            widget.members.add({'userId': data.userId, 'userName': data.userName});
          }
        });
      }
      _addMessage(MessageData(fromUserId: data.userId, fromUsername: '[알림]', message: '${data.userName}이 입장했습니다.', timestamp: data.timestamp));
    }));

    _subs.add(socketService.userLeft.listen((data) {
      if (mounted) {
        setState(() {
          widget.members.removeWhere((member) => member['userId'] == data.userId);
          _callParticipants.removeWhere((p) => p.oderId == data.userId);
        });
      }
      _addMessage(MessageData(fromUserId: data.userId, fromUsername: '[알림]', message: '${data.userName}이 나갔습니다.', timestamp: data.timestamp));

    }));

    _subs.add(socketService.callParticipantsUpdated.listen((data) {
      if (_isDisposed || !mounted) return;
      setState(() {
        _callParticipants = data.participants;
        _totalCallParticipants = data.totalParticipants;
      });
    }));

    _subs.add(socketService.userJoinedCall.listen((data) async {
      if (_isDisposed || !mounted) return;
    }));

    _subs.add(socketService.userLeftCall.listen((data) {
      if (_isDisposed || !mounted) return;
      webRTCService.removePeerConnection(data.userId);
      if (mounted) setState(() {});
    }));

    _subs.add(socketService.peerMuteChanged.listen((data) {
      if (_isDisposed || !mounted) return;
      setState(() {});
    }));

    _subs.add(socketService.receiveMessage.listen((data) {
      _addMessage(data);
    }));


    _subs.add(socketService.receiveMessageProjectWhole.listen((data) {
      _addMessage(MessageData(fromUserId: data.fromUserId, fromUsername: '[전체 메시지]', message: data.message, timestamp: data.timestamp));
    }));

    _subs.add(socketService.roomUpdated.listen((data) {
      setState(() {
        _roomName = data.roomName;
      });
    }));

    _subs.add(socketService.roomDeleted.listen((data) {
      if (data.roomId == widget.roomId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('방이 삭제되었습니다'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
        Navigator.of(context).pop();
      }
    }));

    _subs.add(socketService.trackUpdated.listen((data) {
      timelineController.updateTrack(Track.fromJson(data.track));
    }));

    _subs.add(socketService.trackAdded.listen((data) {
      timelineController.addTrack(Track.fromJson(data.track));
    }));

    _subs.add(socketService.trackDeleted.listen((data) {
      timelineController.deleteTrack(data.trackId);
    }));

    _subs.add(socketService.onPlayStream.listen((data) {
      if (data.raw['currentTime'] is int) {
        timelineController.seekTo(data.raw['currentTime'].toDouble());
      } else {
        timelineController.seekTo(data.raw['currentTime']);
      }
      timelineController.play();
    }));

    _subs.add(socketService.onPauseStream.listen((data) {
      timelineController.pause();
      if (data.raw['currentTime'] is int) {
        timelineController.seekTo(data.raw['currentTime'].toDouble());
      } else {
        timelineController.seekTo(data.raw['currentTime']);
      }
    }));

    _subs.add(socketService.onStopStream.listen((data) {
      timelineController.stop();
    }));

    _subs.add(socketService.timelineHeartbeat.listen((data) {
      if (data.raw['isPlaying']) {

        final currentTime = data.raw['currentTime'] is int
            ? data.raw['currentTime'].toDouble()
            : data.raw['currentTime'];

        // 500ms 이상 차이나면 서버 시간 적용, 그 이하면 건너뜀
        final diff = (currentTime - timelineController.currentTime).abs();
        if(diff > 0.5){
          timelineController.seekTo(currentTime);
        }

        if(!timelineController.isPlaying){
          timelineController.play();
        }

      }
    }));

  }

  void _loadRoomInfo() {
    socketService.getRoomInfo(widget.roomId, (myAuth, roomInfo) {
      if (roomInfo != null) {
        if (mounted) {
          setState(() {
            this.myAuth = myAuth;
          });
        }
      }
    });
  }

  void _loadTimeLine() {
    socketService.getTimeLine(widget.roomId, (timeline) {
      if (timeline != null) {
        timelineController.loadFromMap(timeline);
      }
    });
  }

  void _loadHistoryMessages() {
    socketService.getRoomMessages(widget.roomId, (list) {
      if (mounted) {

        List<MessageData> m = list.map((e) => MessageData.fromJson(e)).toList();

        setState(() {
          messages.addAll(m);
        });
      }
    });
  }

  void _addMessage(MessageData msg) {
    if (mounted) {
      setState(() {
        messages.add(msg);
      });
    }
  }

  void _sendMessage() {
    if (messageController.text.isEmpty) return;
    socketService.sendMessage(messageController.text);
    messageController.clear();
  }

  void _checkActiveCall() {
    socketService.getActiveCall(widget.roomId, (success, data) {
      if (success && data != null && data['hasActiveCall'] == true) {
        if (mounted) {
          setState(() {
            _callParticipants = (data['participants'] as List<dynamic>?)
                ?.map((e) => CallParticipant.fromJson(Map<String, dynamic>.from(e)))
                .toList() ?? [];
            _totalCallParticipants = data['totalParticipants'] ?? 0;
          });
        }
      }
    });
  }

  void _toggleCall() {
    _isInCall ? _leaveCall() : _joinCall();
  }

  void _toggleSidePanel() {
    setState(() {
      _isSidePanelOpen = !_isSidePanelOpen;
      if (_isSidePanelOpen) {
        _sidePanelController.forward();
      } else {
        _sidePanelController.reverse();
      }
    });
  }

  void _joinCall() async {
    final localStream = await webRTCService.initLocalStream();
    if (localStream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 마이크 권한이 필요합니다'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    socketService.joinRoomCall(widget.roomId, _isMuted, (success, data) async {
      if (success) {
        setState(() {
          _isInCall = true;
          _callParticipants = (data['participants'] as List<dynamic>?)
              ?.map((e) => CallParticipant.fromJson(Map<String, dynamic>.from(e)))
              .toList() ?? [];
          _totalCallParticipants = data['totalParticipants'] ?? 0;
        });

        webRTCService.setRoomMode();
        final existingPeers = data['existingParticipants'] ?? [];
        if (existingPeers.isNotEmpty) {
          await webRTCService.connectToExistingPeers(existingPeers);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('⚠️ 통화 참여 실패: ${data?['message'] ?? ''}'),
              behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    });
  }

  void _leaveCall() async {
    socketService.leaveRoomCall(widget.roomId, (success, data) async {
      if (success) {
        setState(() {
          _isInCall = false;
          _isMuted = false;
        });
        await webRTCService.dispose();
        webRTCService = WebRTCService(socketService);
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    webRTCService.toggleAudio(!_isMuted);
    socketService.toggleMute(widget.roomId, _isMuted);
  }

  void _leaveRoom() {
    if (_isSidePanelOpen) _toggleSidePanel();
    if (_isInCall) _leaveCall();
    socketService.leaveRoom();
    Navigator.of(context).pop();
  }

  // ========================================
  // ✅ 오디오 설정 팝업 (FAB 위쪽)
  // ========================================
  void _showAudioSettingsPopup() {
    final RenderBox renderBox =
    _audioSettingsKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    const double popupWidth = 300;
    const double popupHeight = 200;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  right: MediaQuery.of(context).size.width - position.dx - size.width,
                  top: position.dy - popupHeight - 12,
                  child: Material(
                    elevation: 16,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey[850],
                    child: Container(
                      width: popupWidth,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 헤더
                          Row(
                            children: [
                              const Icon(Icons.tune,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                '오디오 설정',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.close,
                                    color: Colors.grey, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 전체 볼륨
                          _buildPopupSliderRow(
                            icon: _speakerVolume == 0
                                ? Icons.volume_off
                                : _speakerVolume < 0.5
                                ? Icons.volume_down
                                : Icons.volume_up,
                            label: '스피커',
                            value: _speakerVolume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) {
                              setDialogState(() => _speakerVolume = v);
                              setState(() => _speakerVolume = v);
                              webRTCService.setMasterVolume(v);
                            },
                          ),
                          const SizedBox(height: 16),

                          // 마이크 게인
                          _buildPopupSliderRow(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            iconColor:
                            _isMuted ? Colors.red.shade300 : Colors.white,
                            label: '마이크',
                            value: _microphoneGain,
                            min: 0.0,
                            max: 2.0,
                            onChanged: _isMuted
                                ? null
                                : (v) {
                              setDialogState(() => _microphoneGain = v);
                              setState(() => _microphoneGain = v);
                              webRTCService.setMicrophoneGain(v);
                            },
                            activeColor: _isMuted ? Colors.grey : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ========================================
  // ✅ 참여자별 볼륨 팝업 (FAB 위쪽)
  // ========================================
  void _showPeerVolumePopup() {
    final RenderBox renderBox =
    _peerVolumeKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    const double popupWidth = 320;

    final participants = _callParticipants
        .where((p) => p.oderId != socketService.loggedInUser.id)
        .toList();
    final double popupHeight =
    participants.isEmpty ? 120 : (80 + participants.length * 98).clamp(120, 420).toDouble();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentParticipants = _callParticipants
                .where((p) => p.oderId != socketService.loggedInUser.id)
                .toList();

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  right: MediaQuery.of(context).size.width - position.dx - size.width,
                  top: position.dy - popupHeight - 12,
                  child: Material(
                    elevation: 16,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey[850],
                    child: Container(
                      width: popupWidth,
                      constraints: BoxConstraints(maxHeight: popupHeight),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 헤더
                          Row(
                            children: [
                              const Icon(Icons.group,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '참여자 볼륨 (${currentParticipants.length}명)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.close,
                                    color: Colors.grey, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (currentParticipants.isEmpty)
                            const Expanded(
                              child: Center(
                                child: Text(
                                  '다른 참여자가 없습니다',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: currentParticipants.map((p) {
                                    final peerId = p.oderId;
                                    final peerName = p.odername;
                                    final vol =
                                    webRTCService.getPeerVolume(peerId);
                                    final muted =
                                    webRTCService.isPeerMuted(peerId);

                                    return Padding(
                                      padding:
                                      const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: muted
                                                    ? Colors.red.shade700
                                                    : Colors.green.shade700,
                                                child: Text(
                                                  (peerName.isNotEmpty ? peerName[0] : '?')
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  peerName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  muted
                                                      ? Icons.volume_off
                                                      : Icons.volume_up,
                                                  color: muted
                                                      ? Colors.red.shade300
                                                      : Colors.white,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  webRTCService
                                                      .togglePeerMute(peerId);
                                                  setDialogState(() {});
                                                  setState(() {});
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                const BoxConstraints(
                                                  minWidth: 36,
                                                  minHeight: 36,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 44,
                                                child: Text(
                                                  muted
                                                      ? '음소거'
                                                      : '${(vol * 100).toInt()}%',
                                                  style: TextStyle(
                                                    color: muted
                                                        ? Colors.red.shade300
                                                        : Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SliderTheme(
                                            data: SliderThemeData(
                                              trackHeight: 4,
                                              thumbShape:
                                              const RoundSliderThumbShape(
                                                  enabledThumbRadius: 7),
                                              overlayShape:
                                              const RoundSliderOverlayShape(
                                                  overlayRadius: 14),
                                              activeTrackColor: muted
                                                  ? Colors.grey
                                                  : Colors.blue,
                                              inactiveTrackColor:
                                              Colors.grey[700],
                                              thumbColor: muted
                                                  ? Colors.grey
                                                  : Colors.blue,
                                            ),
                                            child: Slider(
                                              value: vol,
                                              min: 0.0,
                                              max: 1.0,
                                              divisions: 20,
                                              onChanged: muted
                                                  ? null
                                                  : (value) {
                                                webRTCService
                                                    .setPeerVolume(
                                                    peerId, value);
                                                setDialogState(() {});
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ========================================
  // 팝업 내 슬라이더 행
  // ========================================
  Widget _buildPopupSliderRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
    Color? activeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: activeColor ?? Colors.blue,
            inactiveTrackColor: Colors.grey[700],
            thumbColor: activeColor ?? Colors.blue,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ========================================
  // Build
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[850],
        title: Text('방: $_roomName',
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _leaveRoom,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: _toggleSidePanel,
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _sidePanelAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset:
                Offset(-_sidePanelWidth * _sidePanelController.value, 0),
                child: child,
              );
            },
            child: _buildTimelinePanelContent(),
          ),
          SlideTransition(
            position: _sidePanelAnimation,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: _sidePanelWidth,
                height: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[850]),
                child: _buildSidePanelContent(),
              ),
            ),
          ),
          // 통화 버튼 (드래그로 이동 가능)
          Positioned(
            right: _callButtonRight,
            bottom: _callButtonBottom,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _callButtonRight = (_callButtonRight - details.delta.dx).clamp(0.0, 300.0);
                  _callButtonBottom = (_callButtonBottom - details.delta.dy).clamp(60.0, 600.0);
                });
              },
              onPanEnd: (_) {
                hiveService.saveCallButtonPos(_callButtonRight, _callButtonBottom);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (_totalCallParticipants > 0)
                  FloatingActionButton.small(
                    onPressed: () {},
                    heroTag: 'participants',
                    backgroundColor: Colors.green,
                    child: Text(
                      '$_totalCallParticipants',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                if (_isInCall) ...[
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    key: _peerVolumeKey,
                    onPressed: _showPeerVolumePopup,
                    heroTag: 'peerVolume',
                    backgroundColor: Colors.indigo.shade700,
                    child: const Icon(Icons.group, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    key: _audioSettingsKey,
                    onPressed: _showAudioSettingsPopup,
                    heroTag: 'audioSettings',
                    backgroundColor: Colors.blueGrey.shade700,
                    child: const Icon(Icons.tune, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    onPressed: _toggleMute,
                    heroTag: 'mute',
                    backgroundColor: _isMuted ? Colors.red : Colors.grey[700],
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: _toggleCall,
                  heroTag: 'call',
                  backgroundColor: _isInCall ? Colors.red : Colors.green,
                  child: Icon(
                    _isInCall ? Icons.call_end : Icons.call,
                    color: Colors.white,
                  ),
                ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelinePanelContent() {
    return Column(
      children: [
        Expanded(
          child: TimelineWidget(
            controller: timelineController,
            auth: myAuth,
            roomId: widget.roomId,
          ),
        ),
        _buildCommentPanel(),
      ],
    );
  }

  // 현재 재생 시간에 활성화된 큐들 찾기 (코멘트 오프셋 적용)
  List<Map<String, dynamic>> _getActiveCuesWithOffset() {
    if (timelineController.timelineData == null) return [];

    final currentTime = timelineController.currentTime;
    final activeCues = <Map<String, dynamic>>[];

    if (timelineController.timelineData!.tracks.isEmpty) return [];

    for (var track in timelineController.timelineData!.tracks) {
      for (var cue in track.cues) {
        if (currentTime >= cue.startTime - _commentOffset && currentTime <= cue.endTime) {
          activeCues.add({
            'track': track,
            'cue': cue,
          });
        }
      }
    }

    return activeCues;
  }

  Widget _buildCommentPanel() {
    return AnimatedBuilder(
      animation: timelineController,
      builder: (context, child) {
        final activeCues = _getActiveCuesWithOffset();
        final panelHeight = _isCommentPanelExpanded
            ? _commentPanelMaxHeight
            : _commentPanelMinHeight;

        return Container(
          height: panelHeight,
          decoration: BoxDecoration(
            color: Colors.grey[850],
            border: Border(
              top: BorderSide(color: Colors.grey[700]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // 왼쪽: 아이콘 + 제목 + 배지
                    const Icon(Icons.comment, color: Colors.blue, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      '코멘트',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (activeCues.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeCues.length}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    // 가운데: 접기/펼치기 버튼
                    Expanded(
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            _isCommentPanelExpanded
                                ? Icons.expand_more
                                : Icons.expand_less,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _isCommentPanelExpanded = !_isCommentPanelExpanded;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 구분선
              Divider(height: 1, color: Colors.grey[700], thickness: 1),

              // 코멘트 카드 영역
              Expanded(
                child: activeCues.isEmpty
                    ? const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_outlined, color: Colors.grey, size: 14),
                            SizedBox(width: 6),
                            Text(
                              '활성 코멘트 없음',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: activeCues.length,
                        itemBuilder: (context, index) {
                          final item = activeCues[index];
                          final track = item['track'] as Track;
                          final cue = item['cue'] as Cue;
                          final color = ColorUtils.parseColor(cue.color);

                          return Container(
                            width: 250,
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${track.name} > ${cue.label}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (cue.comment != null && cue.comment!.isNotEmpty)
                                      ? cue.comment!
                                      : '코멘트 없음',
                                  style: TextStyle(
                                    color: (cue.comment != null && cue.comment!.isNotEmpty)
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 13,
                                    fontStyle: (cue.comment != null && cue.comment!.isNotEmpty)
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidePanelContent() {
    return Column(
      children: [
        // 멤버 목록
        Container(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.members.map((member) {
              final isInCall = _callParticipants
                  .any((p) => p.oderId == member['userId']);
              return Chip(
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: isInCall ? Colors.green : Colors.grey[600],
                  child: Icon(
                    isInCall ? Icons.phone_in_talk : Icons.person,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                label: Text(
                  member['userName'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor:
                isInCall ? Colors.green.shade800 : Colors.grey[700],
              );
            }).toList(),
          ),
        ),

        // 채팅
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                  '${messages[index].fromUsername} : ${messages[index].message}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(
                  messages[index].timestamp.toString(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              );
            },
          ),
        ),

        // 메시지 입력
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: '메시지 입력',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, color: Colors.blue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    messageController.dispose();
    _sidePanelController.dispose();

    if (_isInCall) {
      webRTCService.dispose();
    }

    for (final sub in _subs){
      sub.cancel();
    }

    // socketService.offUserJoined();
    // socketService.offUserLeft();
    // socketService.offCallParticipantsUpdated();
    // socketService.offUserJoinedCall();
    // socketService.offUserLeftCall();
    // socketService.offPeerMuteChanged();
    // socketService.offReceiveMessage();
    // socketService.offReceiveMessageProjectWhole();
    // socketService.offRoomUpdated();
    // socketService.offRoomDeleted();
    // socketService.offTrackUpdated();
    // socketService.offTrackAdded();
    // socketService.offTrackDeleted();
    // socketService.offPlay();
    // socketService.offPause();
    // socketService.offStop();
    // socketService.offTimelineHeartBeat();

    socketService.leaveRoom();
    super.dispose();
  }
}

