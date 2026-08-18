
class TimelineData {
  final String projectId;
  final double duration;
  // final int fps;
  final List<Track> tracks;

  TimelineData({
    required this.projectId,
    required this.duration,
    // required this.fps,
    required this.tracks,
  });

  factory TimelineData.fromJson(Map<String, dynamic> json) {
    return TimelineData(
      projectId: json['id'] as String,
      duration: (json['duration'] as num).toDouble(),
      // fps: json['fps'] as int,
      tracks: (json['tracks'] as List<dynamic>)
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Track {
  final String id;
  final String name;
  final String roomId;
  final List<Cue> cues;

  Track({
    required this.id,
    required this.name,
    required this.roomId,
    required this.cues,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      name: json['name'] as String,
      roomId: json['room_id'] as String,
      cues: (json['cues'] as List<dynamic>)
          .map((e) => Cue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Map<String, dynamic> toJson() {
  //   return {
  //     'id': id,
  //     'name': name,
  //     'room_id': roomId,
  //     'cues': cues.map((e) => e.toJson()).toList(),
  //   };
  // }
}

class Cue {
  final String? id;
  final int startTime;
  final int duration;
  final String label;
  final String color;
  final String? comment;
  final Map<String, dynamic>? data;

  Cue({
    this.id,
    required this.startTime,
    required this.duration,
    required this.label,
    required this.color,
    this.comment,
    this.data,
  });

  int get endTime => startTime + duration;

  factory Cue.fromJson(Map<String, dynamic> json) {
    return Cue(
      id: json['id'] as String?,
      startTime: (json['startTime'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      label: json['label'] as String,
      color: json['color'] as String,
      comment: json['comment'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'startTime': startTime,
      'duration': duration,
      'label': label,
      'color': color,
      if (comment != null) 'comment': comment,
      if (data != null) 'data': data,
    };
  }
}


