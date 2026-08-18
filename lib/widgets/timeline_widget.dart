import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../controllers/timeline_controller.dart';
import '../dialog/track_add_dialog.dart';
import '../dialog/track_delete_dialog.dart';
import '../dialog/track_update_dialog.dart';
import '../models/timeline_model.dart';
import '../utils/colorUtils.dart';

class TimelineWidget extends StatefulWidget {
  final TimelineController controller;
  final bool auth;
  final String roomId;

  const TimelineWidget({
    Key? key,
    required this.controller,
    required this.auth,
    required this.roomId,
  }) : super(key: key);

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  final ScrollController _horizontalScrollController = ScrollController(); // 시간 스크롤 (가로)
  final ScrollController _verticalScrollController = ScrollController();   // 트랙 스크롤 (세로)
  final ScrollController _trackLabelsScrollController = ScrollController();
  final ScrollController _trackIconsScrollController = ScrollController();
  bool _isSyncingScroll = false;

  final double trackHeight = 60.0;
  final double timelineHeaderHeight = 40.0;
  final double trackLabelWidth = 120.0;
  final double trackIconLabelWidth = 60.0;

  static const double _minZoom = 0.1;
  static const double _maxZoom = 2.5;

  double _timelineActualWidth = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTimelineUpdate);
    widget.controller.onStopCallback = _scrollToStart;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTimelineUpdate);
    widget.controller.onStopCallback = null;
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _trackLabelsScrollController.dispose();
    _trackIconsScrollController.dispose();
    super.dispose();
  }

  void _onTimelineUpdate() {
    if (widget.controller.isPlaying && _horizontalScrollController.hasClients) {
      final zoom = widget.controller.zoom;
      final pixelsPerSecond = zoom * 50;
      final currentTimePosition = widget.controller.currentTime * pixelsPerSecond;

      if (_timelineActualWidth <= 0) return;

      final targetScroll = currentTimePosition;

      if (targetScroll >= 0 &&
          targetScroll < _horizontalScrollController.position.maxScrollExtent) {
        _horizontalScrollController.jumpTo(targetScroll);
      }
    }
  }

  void _scrollToStart() {
    if (_horizontalScrollController.hasClients) {
      _horizontalScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _syncScroll(ScrollController source) {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    final offset = source.offset;
    if (source != _trackLabelsScrollController && _trackLabelsScrollController.hasClients) {
      _trackLabelsScrollController.jumpTo(offset);
    }
    if (source != _verticalScrollController && _verticalScrollController.hasClients) {
      _verticalScrollController.jumpTo(offset);
    }
    if (source != _trackIconsScrollController && _trackIconsScrollController.hasClients) {
      _trackIconsScrollController.jumpTo(offset);
    }
    _isSyncingScroll = false;
  }

  void _addTracks(String projectId, String roomId) {
    bool roomTrackBool = false;

    for (var track in widget.controller.timelineData!.tracks) {
      if (track.roomId == widget.roomId) {
        roomTrackBool = true;
        break;
      }
    }

    if (roomTrackBool) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방에 해당하는 타임라인이 이미 존재합니다.'))
      );
      return;
    }

    showDialog(
        context: context,
        builder: (context) => AddTrackDialog(
          projectId: projectId,
          roomId: roomId,
          onTimelineAdded: () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('타임라인이 추가되었습니다.'))
            );
          },
        )
    );
  }

  void _updateTracks(String projectId, String trackId, String roomId, String name, List<Cue> cues) {
    showDialog(
      context: context,
      builder: (context) => UpdateTrackDialog(
        projectId: projectId,
        onTimelineUpdated: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('타임라인이 수정됬습니다.'))
          );
        },
        roomId: roomId,
        cueList: cues,
        trackName: name,
        trackId: trackId,
      ),
    );
  }

  void _deleteTracks(String projectId, String trackId, String roomId, String name) {
    showDialog(
      context: context,
      builder: (context) => DeleteTrackDialog(
        projectId: widget.controller.timelineData!.projectId,
        onTrackDeleted: (success, trackId) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('타임라인이 삭제됬습니다.'))
          );
        },
        roomId: roomId,
        trackName: name,
        trackId: trackId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (widget.controller.timelineData == null) {
          return const Center(
            child: Text(
              '타임라인을 로드하세요',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        return Column(
          children: [
            _buildControlPanel(),
            Expanded(
              child: _buildTimelineView(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlPanel() {
    final zoom = widget.controller.zoom;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      color: Colors.grey[850],
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 500) {
            // 세로: 시간 / 줌 두 줄
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: 재생 시간 + 트랙 추가
                Row(
                  children: [
                    Text(
                      _formatTime(widget.controller.currentTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' / ${_formatTime(widget.controller.timelineData!.duration)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const Spacer(),
                    if (widget.auth)
                      IconButton(
                        onPressed: () => _addTracks(widget.controller.timelineData!.projectId, widget.roomId),
                        icon: const Icon(Icons.add, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
                ),
                // Row 2: 줌 컨트롤
                Row(
                  children: [
                    const Text('Zoom:', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: zoom.clamp(_minZoom, _maxZoom),
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: (value) => widget.controller.setZoom(value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            );
          }

          // 가로: 시간 + 줌 한 줄
          return Row(
            children: [
              Text(
                _formatTime(widget.controller.currentTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / ${_formatTime(widget.controller.timelineData!.duration)}',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const Spacer(),
              const Text('Zoom:', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Slider(
                  value: zoom.clamp(_minZoom, _maxZoom),
                  min: _minZoom,
                  max: _maxZoom,
                  onChanged: (value) => widget.controller.setZoom(value),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${zoom.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (widget.auth) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _addTracks(widget.controller.timelineData!.projectId, widget.roomId),
                  icon: const Icon(Icons.add, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineView() {
    final duration = widget.controller.timelineData!.duration;
    final zoom = widget.controller.zoom;
    final timelineWidth = duration * zoom * 50;

    return Container(
      color: Colors.grey[900],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 왼쪽: 트랙 레이블 (고정)
          _buildTrackLabels(),

          // 중앙: 타임라인 콘텐츠
          Expanded(
            child: LayoutBuilder(
                builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_timelineActualWidth != constraints.maxWidth) {
                      setState(() {
                        _timelineActualWidth = constraints.maxWidth;
                      });
                    }
                  });

                  return Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: timelineWidth,
                          child: Column(
                            children: [
                              // 위쪽: 시간 눈금자
                              RepaintBoundary(
                                child: _buildTimeRuler(timelineWidth),
                              ),
                              // 아래쪽: 트랙 콘텐츠 (세로 스크롤)
                              Expanded(
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    _syncScroll(_verticalScrollController);
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    controller: _verticalScrollController,
                                    child: Column(
                                      children: widget.controller.timelineData!.tracks.map(
                                            (track) => _buildTrackContent(track, timelineWidth),
                                      ).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 왼쪽 고정 재생바 (세로선)
                      _buildFixedPlayhead(),
                    ],
                  );
                }),
          ),

          // 오른쪽: 트랙 아이콘 (고정)
          if (widget.auth) _buildTrackIcons(),
        ],
      ),
    );
  }

  // 왼쪽 트랙 레이블 (세로 칼럼)
  Widget _buildTrackLabels() {
    return Container(
      width: trackLabelWidth,
      color: Colors.grey[850],
      child: Column(
        children: [
          // 헤더 (시간 눈금자 높이와 일치)
          Container(
            height: timelineHeaderHeight,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: Border(
                bottom: BorderSide(color: Colors.grey[700]!),
                right: BorderSide(color: Colors.grey[700]!),
              ),
            ),
            child: const Center(
              child: Text(
                'Tracks',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // 트랙 이름 목록 (세로 스크롤)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _syncScroll(_trackLabelsScrollController);
                return false;
              },
              child: SingleChildScrollView(
                controller: _trackLabelsScrollController,
                child: Column(
                  children: widget.controller.timelineData!.tracks.map(
                        (track) => Container(
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[700]!),
                          right: BorderSide(color: Colors.grey[700]!),
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            track.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 오른쪽 트랙 아이콘 (팝업 메뉴)
  Widget _buildTrackIcons() {
    return Container(
      width: trackIconLabelWidth,
      color: Colors.grey[850],
      child: Column(
        children: [
          // 헤더
          Container(
            height: timelineHeaderHeight,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: Border(
                bottom: BorderSide(color: Colors.grey[700]!),
                left: BorderSide(color: Colors.grey[700]!),
              ),
            ),
          ),
          // 아이콘 목록 (세로 스크롤)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _syncScroll(_trackIconsScrollController);
                return false;
              },
              child: SingleChildScrollView(
                controller: _trackIconsScrollController,
                child: Column(
                  children: widget.controller.timelineData!.tracks.map(
                        (track) => Container(
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[700]!),
                          left: BorderSide(color: Colors.grey[700]!),
                        ),
                      ),
                      child: Center(
                        child: PopupMenuButton(
                          icon: const Icon(Icons.menu, color: Colors.white, size: 18),
                          color: Colors.grey[800],
                          tooltip: '타임라인 설정',
                          itemBuilder: (context) => <PopupMenuEntry>[
                            PopupMenuItem(
                              onTap: () => _updateTracks(
                                  widget.controller.timelineData!.projectId,
                                  track.id, track.roomId, track.name, track.cues),
                              child: const ListTile(
                                leading: Icon(Icons.mode, color: Colors.white),
                                title: Text('타임라인 수정', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            PopupMenuItem(
                              onTap: () => _deleteTracks(
                                  widget.controller.timelineData!.projectId,
                                  track.id, track.roomId, track.name),
                              child: const ListTile(
                                leading: Icon(Icons.remove, color: Colors.white),
                                title: Text('타임라인 삭제', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 가로 시간 눈금자
  Widget _buildTimeRuler(double width) {
    return Container(
      height: timelineHeaderHeight,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        border: Border(
          bottom: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      child: CustomPaint(
        painter: TimeRulerPainter(
          duration: widget.controller.timelineData!.duration,
          zoom: widget.controller.zoom,
        ),
      ),
    );
  }

  // 가로 트랙 콘텐츠
  Widget _buildTrackContent(Track track, double width) {
    return Container(
      height: trackHeight,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[850]?.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      child: Stack(
        children: track.cues.map((cue) => _buildCue(cue)).toList(),
      ),
    );
  }

  // 가로 배치 큐
  Widget _buildCue(Cue cue) {
    final zoom = widget.controller.zoom;
    final pixelsPerSecond = zoom * 50;

    final left = cue.startTime * pixelsPerSecond;
    final width = cue.duration * pixelsPerSecond;

    final color = ColorUtils.parseColor(cue.color);
    final isActive = widget.controller.currentTime >= cue.startTime &&
        widget.controller.currentTime <= cue.endTime;

    return Positioned(
      left: left,
      top: 8,
      child: GestureDetector(
        onTap: () => widget.controller.seekTo(cue.startTime.toDouble()),
        child: Container(
          width: width.clamp(20.0, double.infinity),
          height: trackHeight - 16,
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? Colors.white : color.withOpacity(0.5),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ]
                : null,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                cue.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 왼쪽 고정 재생바 (세로선)
  Widget _buildFixedPlayhead() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 2,
            color: Colors.red,
            child: Column(
              children: [
                // 위쪽 삼각형
                Container(
                  width: 0,
                  height: 0,
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(width: 6, color: Colors.transparent),
                      right: BorderSide(width: 6, color: Colors.transparent),
                      bottom: BorderSide(width: 10, color: Colors.red),
                    ),
                  ),
                ),
                Expanded(child: Container()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).floor().toString().padLeft(2, '0');
    final millis = ((seconds % 1) * 100).floor().toString().padLeft(2, '0');
    return '$minutes:$secs.$millis';
  }
}

// 가로 시간 눈금자 Painter
class TimeRulerPainter extends CustomPainter {
  final double duration;
  final double zoom;

  TimeRulerPainter({required this.duration, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final pixelsPerSecond = zoom * 50;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 눈금 간격 동적 조정
    int interval = 1;
    if (zoom < 0.5) {
      interval = 10;
    } else if (zoom < 1.0) {
      interval = 5;
    }

    for (int i = 0; i <= duration; i++) {
      final x = i * pixelsPerSecond;

      if (i % interval == 0) {
        // 주요 눈금 (세로선)
        canvas.drawLine(
          Offset(x, size.height - 15),
          Offset(x, size.height),
          paint..strokeWidth = 2,
        );

        // 시간 텍스트
        textPainter.text = TextSpan(
          text: _formatTime(i.toDouble()),
          style: const TextStyle(color: Colors.white, fontSize: 11),
        );
        textPainter.layout();

        textPainter.paint(canvas, Offset(x + 3, 5));
      } else if (i % (interval ~/ 2) == 0 && interval > 1) {
        // 중간 눈금
        canvas.drawLine(
          Offset(x, size.height - 10),
          Offset(x, size.height),
          paint..strokeWidth = 1,
        );
      } else {
        // 작은 눈금
        canvas.drawLine(
          Offset(x, size.height - 5),
          Offset(x, size.height),
          paint..strokeWidth = 1,
        );
      }
    }
  }

  String _formatTime(double seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).floor().toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  bool shouldRepaint(TimeRulerPainter oldDelegate) {
    return oldDelegate.duration != duration || oldDelegate.zoom != zoom;
  }
}
