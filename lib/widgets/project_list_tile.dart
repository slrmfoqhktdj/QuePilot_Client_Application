import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/project_model.dart';

class ProjectListTile extends StatefulWidget{
  Project project;
  final Function(String, String) onEnterProject;

  ProjectListTile({
    super.key,
    required this.project,
    required this.onEnterProject,
  });

  @override
  State<StatefulWidget> createState() => _ProjectListTileState();
}

class _ProjectListTileState extends State<ProjectListTile> {
  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectName = widget.project.name;
    final projectId = widget.project.id;
    final duration = widget.project.duration;
    // final fps = widget.project.fps;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onEnterProject(projectId, projectName),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 프로젝트 아이콘
                // Container(
                //   width: 60,
                //   height: 60,
                //   decoration: BoxDecoration(
                //     color: Colors.blue.withOpacity(0.2),
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(
                //       color: Colors.blue,
                //       width: 2,
                //     ),
                //   ),
                //   child: const Icon(
                //     Icons.movie,
                //     color: Colors.blue,
                //     size: 32,
                //   ),
                // ),

                // const SizedBox(width: 16),

                // 프로젝트 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ID: ${projectId.substring(0, 8)}...',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.timer,
                            label: '${(duration / 3600).toInt()} 시간',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          // _buildInfoChip(
                          //   icon: Icons.speed,
                          //   label: '${fps} FPS',
                          //   color: Colors.green,
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 입장 버튼
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 정보 칩
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}