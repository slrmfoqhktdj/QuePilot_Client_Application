import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import '../db/hive_service.dart';
import '../models/timeline_model.dart';

class TimelineController extends ChangeNotifier {
  final _hiveService = HiveService();
  TimelineData? _timelineData;
  double _currentTime = 0;
  bool _isPlaying = false;
  Timer? _timer;
  double _playbackSpeed = 1.0;
  late double _zoom;

  // 정지시 호출되는 콜백
  VoidCallback? onStopCallback;

  TimelineController() {
    _zoom = _hiveService.readTimelineZoom();
  }

  TimelineData? get timelineData => _timelineData;
  double get currentTime => _currentTime;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  double get zoom => _zoom;

  // JSON Map에서 직접 로드
  void loadFromMap(Map<String, dynamic> timelineMap) {
    try {
      if (kDebugMode) {
        print("timeline  : ${timelineMap}");
      }
      _timelineData = TimelineData.fromJson(timelineMap);
      _currentTime = 0;
      notifyListeners();
      if (kDebugMode) {
        print('타임라인 로드 성공: ${_timelineData?.tracks.length} 트랙');
      }
    } catch (e) {
      if (kDebugMode) {
        print('타임라인 로드 실패: $e');
      }
    }
  }

  // JSON 문자열에서 로드
  void loadFromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      loadFromMap(jsonData);
    } catch (e) {
      if (kDebugMode) {
        print('타임라인 파싱 실패: $e');
      }
    }
  }

  // 타임라인 전체 업데이트
  void updateTimeline(Map<String, dynamic> timelineMap) {
    try {
      final currentPlayingState = _isPlaying;
      final currentTime = _currentTime;

      _timelineData = TimelineData.fromJson(timelineMap);

      // 재생 상태 유지
      if (currentPlayingState) {
        _currentTime = currentTime;
      }

      notifyListeners();
      if (kDebugMode) {
        print('타임라인 업데이트됨');
      }
    } catch (e) {
      if (kDebugMode) {
        print('타임라인 업데이트 실패: $e');
      }
    }
  }

  // 큐 추가
  void addCueToTrack(String trackId, Cue cue) {
    if (_timelineData == null) return;

    final trackIndex = _timelineData!.tracks.indexWhere((t) => t.id == trackId);
    if (trackIndex != -1) {
      final track = _timelineData!.tracks[trackIndex];
      final updatedCues = List<Cue>.from(track.cues)..add(cue);

      final updatedTrack = Track(
        id: track.id,
        name: track.name,
        roomId: track.roomId,
        cues: updatedCues,
      );

      final updatedTracks = List<Track>.from(_timelineData!.tracks);
      updatedTracks[trackIndex] = updatedTrack;

      _timelineData = TimelineData(
        projectId: _timelineData!.projectId,
        duration: _timelineData!.duration,
        // fps: _timelineData!.fps,
        tracks: updatedTracks,
      );

      notifyListeners();
    }
  }

  // 큐 업데이트
  void updateCueInTrack(String trackId, String cueId, Cue updatedCue) {
    if (_timelineData == null) return;

    final trackIndex = _timelineData!.tracks.indexWhere((t) => t.id == trackId);
    if (trackIndex != -1) {
      final track = _timelineData!.tracks[trackIndex];
      final cueIndex = track.cues.indexWhere((c) => c.id == cueId);

      if (cueIndex != -1) {
        final updatedCues = List<Cue>.from(track.cues);
        updatedCues[cueIndex] = updatedCue;

        final updatedTrack = Track(
          id: track.id,
          name: track.name,
          roomId: track.roomId,
          cues: updatedCues,
        );

        final updatedTracks = List<Track>.from(_timelineData!.tracks);
        updatedTracks[trackIndex] = updatedTrack;

        _timelineData = TimelineData(
          projectId: _timelineData!.projectId,
          duration: _timelineData!.duration,
          // fps: _timelineData!.fps,
          tracks: updatedTracks,
        );

        notifyListeners();
      }
    }
  }

  // 큐 삭제
  void deleteCueFromTrack(String trackId, String cueId) {
    if (_timelineData == null) return;

    final trackIndex = _timelineData!.tracks.indexWhere((t) => t.id == trackId);
    if (trackIndex != -1) {
      final track = _timelineData!.tracks[trackIndex];
      final updatedCues = track.cues.where((c) => c.id != cueId).toList();

      final updatedTrack = Track(
        id: track.id,
        name: track.name,
        roomId: track.roomId,
        cues: updatedCues,
      );

      final updatedTracks = List<Track>.from(_timelineData!.tracks);
      updatedTracks[trackIndex] = updatedTrack;

      _timelineData = TimelineData(
        projectId: _timelineData!.projectId,
        duration: _timelineData!.duration,
        // fps: _timelineData!.fps,
        tracks: updatedTracks,
      );

      notifyListeners();
    }
  }

  // 트랙 추가
  void addTrack(Track track) {
    if (_timelineData == null) return;

    final updatedTracks = List<Track>.from(_timelineData!.tracks)..add(track);

    _timelineData = TimelineData(
      projectId: _timelineData!.projectId,
      duration: _timelineData!.duration,
      // fps: _timelineData!.fps,
      tracks: updatedTracks,
    );

    notifyListeners();
  }

  // 트랙 추가
  void updateTrack(Track track) {
    if (_timelineData == null) return;

    final updatedTracks = List<Track>.from(_timelineData!.tracks);
    final trackIndex = updatedTracks.indexWhere((t) => t.id == track.id);

    updatedTracks[trackIndex] = track;

    _timelineData = TimelineData(
      projectId: _timelineData!.projectId,
      duration: _timelineData!.duration,
      // fps: _timelineData!.fps,
      tracks: updatedTracks,
    );

    notifyListeners();
  }

  void deleteTrack(String trackId) {
    if (_timelineData == null) return;

    final trackIndex = _timelineData!.tracks.indexWhere((t) => t.id == trackId);
    if (trackIndex != -1) {
      _timelineData!.tracks.removeAt(trackIndex);

      notifyListeners();
    }
  }

  // 재생/일시정지 토글
  void togglePlayback() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  // 재생
  void play() {
    if (_timelineData == null) return;

    _isPlaying = true;
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _currentTime += 0.033 * _playbackSpeed;

      if (_currentTime >= _timelineData!.duration) {
        _currentTime = _timelineData!.duration;
        pause();
      }

      notifyListeners();
    });
    notifyListeners();
  }

  // 일시정지
  void pause() {
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  // 정지
  void stop() {
    pause();
    _currentTime = 0;
    notifyListeners();

    onStopCallback?.call();
  }

  // 특정 시간으로 이동
  void seekTo(double time) {
    if (_timelineData == null) return;
    _currentTime = time.clamp(0, _timelineData!.duration);
    notifyListeners();
  }

  // 재생 속도 변경
  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    notifyListeners();
  }

  // 줌 레벨 변경
  void setZoom(double zoom) {
    _zoom = zoom.clamp(0.1, 10.0);
    _hiveService.saveTimelineZoom(_zoom);
    notifyListeners();
  }

  // 현재 활성 큐 찾기
  List<Cue> getActiveCues() {
    if (_timelineData == null) return [];

    List<Cue> activeCues = [];
    for (var track in _timelineData!.tracks) {
      for (var cue in track.cues) {
        if (_currentTime >= cue.startTime && _currentTime <= cue.endTime) {
          activeCues.add(cue);
        }
      }
    }
    return activeCues;
  }

  // 타임라인 데이터를 Map으로 변환
  // Map<String, dynamic>? toMap() {
  //   return _timelineData?.toJson();
  // }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}



