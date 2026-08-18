import 'package:hive_flutter/hive_flutter.dart';
import 'package:quepilot_client_01/db/model/hive_key_model.dart';

class HiveService {
  static final HiveService _singleton = HiveService._internal();

  HiveService._internal();

  Box? _projectIndexBox;
  Box? _trackIndexBox;
  Box? _optionBox;

  factory HiveService() {
    return _singleton;
  }

  initHiveManager() async {
    await Hive.initFlutter();

    await openProjectIndex();
    await openTrackIndex();
    await openOption();
  }

  Future openProjectIndex() async {
    _projectIndexBox = await Hive.openBox(HiveKeyModel().projectIndexBoxKey);
  }

  Future openTrackIndex() async {
    _trackIndexBox = await Hive.openBox(HiveKeyModel().trackIndexBoxKey);
  }

  Future openOption() async {
    _optionBox = await Hive.openBox(HiveKeyModel().optionBoxKey);
  }

  Future projectDelete(String key) async {
    return _projectIndexBox?.delete(key);
  }

  Future trackDelete(String key) async {
    return _trackIndexBox?.delete(key);
  }

  Future optionDelete(String key) async {
    return _optionBox?.delete(key);
  }


  Future projectSaveInt(String key, int value) async {
    return _projectIndexBox?.put(key, value);
  }

  Future trackSaveInt(String key, int value) async {
    return _trackIndexBox?.put(key, value);
  }

  Future optionSaveInt(String key, int value) async {
    return _optionBox?.put(key, value);
  }

  Future optionSaveString(String key, String value) async {
    return _optionBox?.put(key, value);
  }

  Future optionSaveMap(String key, Map<String,dynamic> value) async {
    return _optionBox?.put(key, value);
  }

  int? projectReadInt(String key, int? defaultValue) {
    return _projectIndexBox?.get(key, defaultValue: defaultValue);
  }

  int? trackReadInt(String key, int? defaultValue) {
    return _trackIndexBox?.get(key, defaultValue: defaultValue);
  }

  int? optionReadInt(String key, int? defaultValue) {
    return _optionBox?.get(key, defaultValue: defaultValue);
  }

  String? optionReadString(String key, String? defaultValue) {
    return _optionBox?.get(key, defaultValue: defaultValue);
  }

  Map<String,dynamic>? optionReadMap(String key) {
    final data = _optionBox?.get(key);
    if(data == null) return null;
    return Map<String,dynamic>.from(data);
  }

  Future projectIndexClear() async {
    return _projectIndexBox?.clear();
  }

  Future trackIndexClear() async {
    return _trackIndexBox?.clear();
  }

  Future optionClear() async {
    return _optionBox?.clear();
  }

  // 코멘트 오프셋 (큐 시작 전 코멘트 표시 시간)
  Future saveCommentOffset(double value) async {
    return _optionBox?.put(HiveKeyModel().commentOffsetKey, value.toString());
  }

  double readCommentOffset() {
    final value = _optionBox?.get(HiveKeyModel().commentOffsetKey);
    if (value != null) {
      return double.tryParse(value.toString()) ?? 2.0;
    }
    return 2.0;
  }

  // 통화 버튼 위치 (right, bottom)
  Future saveCallButtonPos(double right, double bottom) async {
    return _optionBox?.put(HiveKeyModel().callButtonPosKey, '$right,$bottom');
  }

  List<double> readCallButtonPos() {
    final value = _optionBox?.get(HiveKeyModel().callButtonPosKey);
    if (value != null) {
      final parts = value.toString().split(',');
      if (parts.length == 2) {
        return [
          double.tryParse(parts[0]) ?? 16,
          double.tryParse(parts[1]) ?? 100,
        ];
      }
    }
    return [16, 100];
  }

  // 타임라인 줌
  Future saveTimelineZoom(double value) async {
    return _optionBox?.put(HiveKeyModel().timelineZoomKey, value.toString());
  }

  double readTimelineZoom() {
    final value = _optionBox?.get(HiveKeyModel().timelineZoomKey);
    if (value != null) {
      return double.tryParse(value.toString()) ?? 1.0;
    }
    return 1.0;
  }
}