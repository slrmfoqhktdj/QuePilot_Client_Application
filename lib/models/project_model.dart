class Project {
  final String id;
  final String name;
  final int duration;
  // final int fps;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    required this.duration,
    // required this.fps,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      duration: json['duration'] as int,
      // fps: json['fps'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson(){
    return {
      'id' : id,
      'name' : name,
      'duration': duration,
      // 'fps': fps,
      'created_at' : createdAt,
    };
  }

  @override
  bool operator ==(Object other) {
    if(identical(this, other)) return true;
    return super == other;
  }

  @override
  int get hashCode => id.hashCode;
}