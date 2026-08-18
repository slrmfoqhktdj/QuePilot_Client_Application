class User{
  final String id;
  final String login_id;
  final String name;

  User({
    required this.id,
    required this.login_id,
    required this.name,
  });

  factory User.fromJson(Map<String, dynamic> json){
    return User(
      id: json['id'] as String,
      login_id: json['login_id'] as String,
      name: json['name'] as String,

    );
  }

  Map<String, dynamic> toJson(){
    return {
      'id' : id,
      'login_id' : login_id,
      'name' : name,
    };
  }
}