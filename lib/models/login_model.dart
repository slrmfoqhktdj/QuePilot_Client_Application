import 'package:quepilot_client_01/models/user_model.dart';

class Login{
  final User user;
  final String sessionCookie;

  Login({
    required this.user,
    required this.sessionCookie,
  });

  factory Login.fromJson(Map<String, dynamic> json){
    return Login(
      user: User.fromJson(Map<String, dynamic>.from(json['user'])),
      sessionCookie: json['sessionCookie'] as String,
    );
  }

  Map<String, dynamic> toJson(){
    return {
      'user' : user.toJson(),
      'sessionCookie' : sessionCookie,
    };
  }
}