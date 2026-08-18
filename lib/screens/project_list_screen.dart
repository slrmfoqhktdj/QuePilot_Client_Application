import 'package:flutter/material.dart';
import 'package:quepilot_client_01/models/project_model.dart';
import 'package:quepilot_client_01/widgets/project_list_tile.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import 'room_list_screen.dart';

class ProjectListScreen extends StatefulWidget {
  // final User userInfo;

  const ProjectListScreen({
    super.key,
    // required this.userInfo,
  });

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final socketService = SocketService();
  List<Project> projects = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // socketService.connectToMainServer(
    //         () {
    //           if(mounted){
    //             setState(() {
    //               _isLoading = true;
    //             });
    //           }
    //
    //             },
    //         () {
    //           if(mounted) {
    //             setState(() {
    //               _isLoading = false;
    //             });
    //           }
    //             },
    //         (err){
    //           if(mounted) {
    //             setState(() {
    //               _isLoading = false;
    //             });
    //           }
    //             },
    // );


    _loadProjects();
  }

  void _loadProjects() {
    setState(() {
      _isLoading = true;
    });

    socketService.getProjectList((projectList) {
      if (mounted) {
        setState(() {
          projects = projectList.map<Project>((projectInfo) {
            return Project.fromJson(projectInfo);
          }).toList();
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _enterProject(String projectId, String projectName) async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    await socketService.connectToProject(
      projectId,
          () {
        // 연결 성공
        if (mounted) {
          Navigator.pop(context); // 로딩 다이얼로그 닫기
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoomListScreen(
                projectId: projectId,
                projectName : projectName,
              ),
            ),
          ).then((_){
            _loadProjects();
          });
        }
      },
          (error) {
        // 연결 실패
        if (mounted) {
          Navigator.pop(context); // 로딩 다이얼로그 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('프로젝트 연결 실패: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[850],
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                socketService.loggedInUser.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  socketService.loggedInUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  socketService.loggedInUser.login_id,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadProjects,
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
              '프로젝트 목록 로딩 중...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      )
          : projects.isEmpty
          ? _buildEmptyState()
          : _buildProjectList(),
    );
  }

  // ✅ 빈 상태 화면
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 100,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 24),
          Text(
            '프로젝트가 없습니다',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '관리자에게 프로젝트 접근 권한을 요청하세요',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadProjects,
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

  // ✅ 프로젝트 리스트
  Widget _buildProjectList() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadProjects();
      },
      color: Colors.blue,
      backgroundColor: Colors.grey[850],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
          return ProjectListTile(project: project, onEnterProject: (String projectId, String projectName) {_enterProject(projectId, projectName);},);
        },
      ),
    );
  }
  //
  // // ✅ 프로젝트 카드
  // Widget _buildProjectCard(Map<String, dynamic> project, int index) {
  //   final projectName = project['name'] ?? 'Unknown';
  //   final projectId = project['id'] ?? '';
  //   final duration = project['duration'] ?? 0;
  //   final fps = project['fps'] ?? 30;
  //
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 12),
  //     decoration: BoxDecoration(
  //       color: Colors.grey[850],
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(
  //         color: Colors.grey[800]!,
  //         width: 1,
  //       ),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.3),
  //           blurRadius: 8,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Material(
  //       color: Colors.transparent,
  //       child: InkWell(
  //         onTap: () => _enterProject(projectId, projectName),
  //         borderRadius: BorderRadius.circular(16),
  //         child: Padding(
  //           padding: const EdgeInsets.all(16),
  //           child: Row(
  //             children: [
  //               // 프로젝트 아이콘
  //               Container(
  //                 width: 60,
  //                 height: 60,
  //                 decoration: BoxDecoration(
  //                   color: Colors.blue.withOpacity(0.2),
  //                   borderRadius: BorderRadius.circular(12),
  //                   border: Border.all(
  //                     color: Colors.blue,
  //                     width: 2,
  //                   ),
  //                 ),
  //                 child: const Icon(
  //                   Icons.movie,
  //                   color: Colors.blue,
  //                   size: 32,
  //                 ),
  //               ),
  //
  //               const SizedBox(width: 16),
  //
  //               // 프로젝트 정보
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       projectName,
  //                       style: const TextStyle(
  //                         color: Colors.white,
  //                         fontSize: 18,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                     const SizedBox(height: 6),
  //                     Text(
  //                       'ID: ${projectId.substring(0, 8)}...',
  //                       style: TextStyle(
  //                         color: Colors.grey[500],
  //                         fontSize: 12,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 8),
  //                     Row(
  //                       children: [
  //                         _buildInfoChip(
  //                           icon: Icons.timer,
  //                           label: '${duration}s',
  //                           color: Colors.orange,
  //                         ),
  //                         const SizedBox(width: 8),
  //                         _buildInfoChip(
  //                           icon: Icons.speed,
  //                           label: '${fps} FPS',
  //                           color: Colors.green,
  //                         ),
  //                       ],
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //
  //               // 입장 버튼
  //               Container(
  //                 width: 48,
  //                 height: 48,
  //                 decoration: BoxDecoration(
  //                   color: Colors.blue,
  //                   borderRadius: BorderRadius.circular(12),
  //                 ),
  //                 child: const Icon(
  //                   Icons.arrow_forward,
  //                   color: Colors.white,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  //
  // // ✅ 정보 칩
  // Widget _buildInfoChip({
  //   required IconData icon,
  //   required String label,
  //   required Color color,
  // }) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.2),
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: color, width: 1),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(icon, size: 14, color: color),
  //         const SizedBox(width: 4),
  //         Text(
  //           label,
  //           style: TextStyle(
  //             color: color,
  //             fontSize: 11,
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  void dispose() {
    super.dispose();
  }
}