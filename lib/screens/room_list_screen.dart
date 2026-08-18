import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quepilot_client_01/models/room_model.dart';
import 'package:quepilot_client_01/widgets/room_list_tile.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import 'room_screen.dart';

class RoomListScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  // final User userInfo;

  const RoomListScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    // required this.userInfo,
  });

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final socketService = SocketService();
  final List<StreamSubscription> _subs = [];
  List<Room> rooms = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print("initstate load rooms");
    WidgetsBinding.instance.addPostFrameCallback((_){
      _setupEventListeners();
      _loadRooms();
    });

  }

  void _loadRooms() {
    if(!mounted){
      return;
    }

    setState(() {
      _isLoading = true;
    });

    socketService.getAllRooms((roomList) {
      if (mounted) {
        setState(() {
          rooms = roomList.map<Room>((room) {
            return Room.fromJson(room);
          }).toList();
          _isLoading = false;
        });
      }
    });
  }

  void _setupEventListeners() {

    _subs.add(socketService.roomCreated.listen( (data) {
      if (mounted) {
        setState(() {
          rooms.add(Room(id: data.roomId, name: data.roomName, createdAt: data.createdAt));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('새로운 방 "${data.roomName}"이(가) 생성되었습니다'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }));

    _subs.add(socketService.roomUpdated.listen((data) {
      int index = rooms.indexWhere((room) => room.id == data.roomId);
      if (index != -1 && mounted) {
        setState(() {
          rooms[index] = Room(
            id: rooms[index].id,
            name: data.roomName,
            createdAt: rooms[index].createdAt,
          );
        });
      }
    }));

    _subs.add(socketService.roomDeleted.listen((data) {
      if (mounted) {
        setState(() {
          rooms.removeWhere((room) => room.id == data.roomId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('방이 삭제되었습니다'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }));

  }

  Future<void> _exitToProjectList() async {
    // _removeEventListeners();

    await socketService.socketOut();

    await Future.delayed(const Duration(milliseconds: 500));

    socketService.connectToMainServer(
        (){
          print('메인서버 재연결 완료');
        },
        (){
          print('메인서버 연결 해제');
        },
        (error){
          print('메인서버 재연결 오류 $error');
        }
    );

    if(mounted){
      Navigator.pop(context);
    }
  }

  void _joinRoom(String roomId, String roomName) {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      ),
    );

    socketService.joinRoom(
      roomId,
          (success, members) {
        if (mounted) {
          Navigator.pop(context); // 로딩 다이얼로그 닫기

          if (success) {
            _navigateToRoom(roomId, roomName, members);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('방 입장에 실패했습니다'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  void _navigateToRoom(
      String roomId,
      String roomName,
      List<Map<String, dynamic>> members,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomScreen(
          roomId: roomId,
          roomName: roomName,
          members: members,
        ),
      ),
    );
  }

  // void _removeEventListeners(){
  //   socketService.offRoomCreated();
  //   socketService.offRoomUpdated();
  //   socketService.offRoomDeleted();
  // }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop,result) {
        if (!didPop) {
          _exitToProjectList();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[900],
          appBar: AppBar(
            backgroundColor: Colors.grey[850],
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _exitToProjectList,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.projectName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.projectId,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadRooms,
                tooltip: '새로고침',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  '방 목록 로딩 중...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          )
              : rooms.isEmpty
              ? _buildEmptyState()
              : _buildRoomList(),
        )
    );

  }

  // ✅ 빈 상태 화면
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room,
            size: 100,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 24),
          Text(
            '방이 없습니다',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '관리자가 생성한 방이 여기에 표시됩니다',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadRooms,
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 방 리스트
  Widget _buildRoomList() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadRooms();
      },
      color: Colors.blue,
      backgroundColor: Colors.grey[850],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return RoomListTile(room:room, onJoinRoom: (roomId,roomName) => _joinRoom(roomId, roomName),);
        },
      ),
    );
  }


  @override
  void dispose() {
    // _removeEventListeners();

    for (final sub in _subs){
      sub.cancel();
    }

    super.dispose();
  }
}

