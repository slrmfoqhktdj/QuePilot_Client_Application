import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quepilot_client_01/dialog/question_dialog.dart';
import 'package:quepilot_client_01/models/message_model.dart';
import 'package:quepilot_client_01/screens/login_screen.dart';
import 'package:quepilot_client_01/services/socket_service.dart';

class ChattingsScreen extends StatefulWidget {
  final void Function(void Function(MessageData) callback) onRegisterCallback;
  const ChattingsScreen({
    Key? key,
    required this.onRegisterCallback,
  }) : super(key:key);

  @override
  State<ChattingsScreen> createState() => _ChattingsScreenState();
}

class _ChattingsScreenState extends State<ChattingsScreen> with AutomaticKeepAliveClientMixin{

  final socketService = SocketService();
  List<MessageData> messages = [];
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;     // 탭 전환시에도 state 유지

  @override
  void initState(){
    super.initState();
    // _setupEventListeners();

    _loadHistoryMessages();

    widget.onRegisterCallback((message) {
      if(mounted){
        setState(() {
          _addMessage(message);
        });
      }
    });

  }




  void _loadHistoryMessages() {
    socketService.getPersonalMessages(socketService.loggedInUser.id, (list) {
      if (mounted) {

        List<MessageData> m = list.map((e) => MessageData.fromJson({...e,'fromUsername': e['fromUserId'] == socketService.loggedInUser.id ? socketService.loggedInUser.name : 'admin'})).toList();

        setState(() {
          messages.addAll(m);
        });
      }
    });

    _scrollToBottom();
  }

  @override
  void dispose(){
    // socketService.offReceivePersonalMessage();
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // void _setupEventListeners() {
  //   socketService.onReceivePersonalMessage((Data) {
  //     _addMessage(Data);
  //   });
  // }

  void _sendMessage() {
    if (messageController.text.isEmpty) return;

    socketService.sendPersonalMessage('admin', messageController.text, (success, message) {
      if(success && mounted){
        _addMessage(message);
      }
    });
    messageController.clear();
  }

  void _addMessage(MessageData message) {
    if(this.mounted){
      setState(() {
        messages.add(message);
      });
      _scrollToBottom();
    }

  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut
        );
      }
    });
  }

  @override
  Widget build(BuildContext context){
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const Row(
            children: [
              Icon(Icons.chat, color: Colors.white,),
              SizedBox(width: 12,),
              Text('개인 채팅',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),)
            ],
          ),
        ),
        backgroundColor: Colors.grey[850],
      ),
      backgroundColor: Colors.grey[900],
      body:Container(
        color: Colors.grey[900],
        child: _buildSidePanelContent(),
      ),
    );
  }

  Widget _buildSidePanelContent() {
    return Column(
      children: [
        // 채팅창
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text('${messages[index].fromUsername} : ${messages[index].message} - ${messages[index].timestamp.toString()}',style: TextStyle(color: Colors.white),),
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
                  style: TextStyle(color: Colors.white),
                  controller: messageController,
                  decoration: const InputDecoration(
                    hintText: '메시지 입력',
                    hintStyle: TextStyle(color: Colors.white),
                    border: OutlineInputBorder(),
                  ),

                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sendMessage,
                child: const Text('전송'),
              ),
            ],
          ),
        ),
      ],
    );
  }

}