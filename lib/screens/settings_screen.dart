import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quepilot_client_01/db/model/hive_key_model.dart';
import 'package:quepilot_client_01/dialog/question_dialog.dart';
import 'package:quepilot_client_01/screens/login_screen.dart';
import 'package:quepilot_client_01/services/socket_service.dart';

import '../db/hive_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key:key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  final socketService = SocketService();
  final hiveService = HiveService();
  double _commentOffset = 2.0;

  @override
  void initState(){
    super.initState();
    _commentOffset = hiveService.readCommentOffset();
  }

  @override
  void dispose(){
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const Row(
            children: [
              Icon(Icons.settings, color: Colors.white,),
              SizedBox(width: 12,),
              Text('설정',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),)
            ],
          ),
        ),
        backgroundColor: Colors.grey[850],
      ),
      backgroundColor: Colors.grey[900],
      body:Container(
        color: Colors.grey[900],
        child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 16,),
            Card(
              color: Colors.grey[850],
              child: ListTile(
                leading: const Icon(Icons.label_outline, color: Colors.white,),
                title: const Text('서버 URL', style: TextStyle(color: Colors.white),),
                subtitle: Text(socketService.serverUrl, style: TextStyle(color: Colors.grey[400]),),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue,),
                  onPressed: () {

                  },
                ),
              ),
            ),
            SizedBox(height: 16,),
            Card(
              color: Colors.grey[850],
              child: SwitchListTile(
                secondary: const Icon(Icons.dark_mode, color: Colors.white),
                title: const Text('다크 모드', style: TextStyle(color: Colors.white),),
                value: true,
                onChanged: (value) {},
              ),
            ),
            SizedBox(height: 16,),
            // ── 코멘트 표시 시점 ──
            Card(
              color: Colors.grey[850],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.white),
                        const SizedBox(width: 12),
                        const Text(
                          '코멘트 표시 시점',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_commentOffset.toStringAsFixed(1)}초',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '큐 시작 전 코멘트를 표시하는 시간',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _commentOffset,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey[700],
                      onChanged: (value) {
                        setState(() {
                          _commentOffset = value;
                        });
                        hiveService.saveCommentOffset(value);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0초', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        Text('5초', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        Text('10초', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16,),
            Card(
              color: Colors.grey[850],
              child: ListTile(
                leading: const Icon(Icons.label_outline, color: Colors.white,),
                title: const Text('로그아웃', style: TextStyle(color: Colors.white),),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (dialogContext) => QuestionAlertDialog(
                          question: '로그아웃 하시겠습니까?',
                          confirmedText: '로그아웃',
                          onConfirmed: () async {
                            socketService.logout();

                            await hiveService.optionDelete(HiveKeyModel().keyAutoLoginOption);

                            Navigator.pop(dialogContext);
                            // 빠른 해체후 연결은 연속 접속의 원인이 됨
                            await Future.delayed(const Duration(seconds: 1)).then(((_){}));
                            if(mounted){
                              Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    // builder: (context) => ProjectListScreen(userInfo:userInfo),
                                    builder: (context) => LoginScreen(),
                                  ), (route) => false
                              );
                            }

                          }
                      )
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

}