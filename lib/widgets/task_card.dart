import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/widgets/text.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final bool showProject;
  
  const TaskCard({
    Key? key,
    required this.task,
    this.onTap,
    this.showProject = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Kiểm tra task có quá hạn không
    bool isOverdue = false;
    try {
      final dateFormat = task.deadlineDate.split('/');
      if (dateFormat.length == 3) {
        final deadline = DateTime(
          int.parse(dateFormat[2]), 
          int.parse(dateFormat[1]), 
          int.parse(dateFormat[0])
        );
        isOverdue = DateTime.now().isAfter(deadline) && task.status != 'completed';
      }
    } catch (e) {
      print('Lỗi khi kiểm tra hạn chót: $e');
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isOverdue 
                ? Colors.red.withOpacity(0.7) 
                : _getStatusColor(task.status).withOpacity(0.5),
            width: isOverdue ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Hiển thị badge quá hạn nếu cần
                        if (isOverdue)
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, color: Colors.white, size: 12),
                                SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    'Quá hạn',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Flexible(child: _buildPriorityBadge(task.priority)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task.description.isNotEmpty) ...[
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isOverdue ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      "${task.deadlineDate} ${task.deadlineTime}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? Colors.red : Colors.grey[600],
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showProject) ...[
                    const SizedBox(width: 8),
                    Text(
                      "·",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.projectName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Flexible(child: _buildStatusIndicator(task.status)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPriorityBadge(String priority) {
    Color color;
    IconData icon;
    String text;

    switch (priority.toLowerCase()) {
      case 'urgent':
        color = Colors.red;
        icon = Icons.priority_high;
        text = 'Khẩn cấp';
        break;
      case 'high':
        color = Colors.orange;
        icon = Icons.arrow_upward;
        text = 'Cao';
        break;
      case 'low':
        color = Colors.blue;
        icon = Icons.arrow_downward;
        text = 'Thấp';
        break;
      default:
        color = Colors.grey;
        icon = Icons.remove;
        text = 'Bình thường';
        break;
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 120), // Giới hạn chiều rộng tối đa
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusIndicator(String status) {
    return Container(
      constraints: BoxConstraints(maxWidth: 100), // Giới hạn chiều rộng tối đa
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          fontSize: 10,
          color: _getTextColorForStatus(status),
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
  
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Hoàn thành';
      case 'in progress':
        return 'Đang thực hiện';
      default:
        return 'Chờ xử lý';
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.taskCompleted;
      case 'in progress':
        return AppColors.taskInProgress;
      default:
        return AppColors.taskPending;
    }
  }
  
  Color _getTextColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade800;
      case 'in progress':
        return Colors.blue.shade800;
      default:
        return Colors.red.shade800;
    }
  }
}