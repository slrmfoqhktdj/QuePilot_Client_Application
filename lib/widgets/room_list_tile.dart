import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/room_model.dart';

class RoomListTile extends StatefulWidget{
  final Room room;
  final Function(String, String) onJoinRoom;

  RoomListTile({
    Key? key,
    required this.room,
    required this.onJoinRoom,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RoomListTileState();
}

class _RoomListTileState extends State<RoomListTile> {
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
          onTap: () => widget.onJoinRoom(widget.room.id, widget.room.name),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 방 아이콘
                // Container(
                //   width: 60,
                //   height: 60,
                //   decoration: BoxDecoration(
                //     gradient: LinearGradient(
                //       begin: Alignment.topLeft,
                //       end: Alignment.bottomRight,
                //       colors: [
                //         Colors.green.withOpacity(0.3),
                //         Colors.green.withOpacity(0.1),
                //       ],
                //     ),
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(
                //       color: Colors.green,
                //       width: 2,
                //     ),
                //   ),
                //   child: const Icon(
                //     Icons.meeting_room,
                //     color: Colors.green,
                //     size: 32,
                //   ),
                // ),
                //
                // const SizedBox(width: 16),

                // 방 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.room.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: _formatDate(widget.room.createdAt),
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),

                // 입장 버튼
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green,
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

  // ✅ 날짜 포맷
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return '오늘';
    } else if (dateOnly == yesterday) {
      return '어제';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}