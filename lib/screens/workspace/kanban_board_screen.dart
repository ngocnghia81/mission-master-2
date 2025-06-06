import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/tasks/tasks_bloc.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/screens/task/task_detail_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const KanbanBoardScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  final List<String> _columns = ['Chờ xử lý', 'Đang thực hiện', 'Hoàn thành'];
  final Map<String, String> _statusMap = {
    'Chờ xử lý': 'none',
    'Đang thực hiện': 'in progress',
    'Hoàn thành': 'completed',
  };
  final Map<String, Color> _columnColors = {
    'Chờ xử lý': AppColors.taskPending,
    'Đang thực hiện': AppColors.taskInProgress,
    'Hoàn thành': AppColors.taskCompleted,
  };
  
  bool _isLoading = true;
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy tất cả các task trong project
      final QuerySnapshot taskSnapshot = await FirebaseFirestore.instance
          .collection('Tasks')
          .doc(widget.projectId)
          .collection('projectTasks')
          .get();
      
      List<Task> tasks = [];
      for (var doc in taskSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        List<String> members = [];
        if (data['Members'] != null) {
          if (data['Members'] is List) {
            members = List<String>.from(data['Members']);
          } else if (data['Members'] is String) {
            members = [data['Members'] as String];
          }
        }
        
        tasks.add(Task(
          id: doc.id,
          title: data['taskName'] ?? '',
          description: data['description'] ?? '',
          deadlineDate: data['deadlineDate'] ?? '',
          deadlineTime: data['deadlineTime'] ?? '',
          members: members,
          status: data['status'] ?? 'none',
          projectName: data['projectName'] ?? '',
          projectId: widget.projectId,
          priority: data['priority'] ?? 'normal',
        ));
      }
      
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
      );
    }
  }

  Future<void> _updateTaskStatus(Task task, String newStatus) async {
    try {
      // Cập nhật trạng thái trong Firestore
      await FirebaseFirestore.instance
          .collection('Tasks')
          .doc(widget.projectId)
          .collection('projectTasks')
          .doc(task.id)
          .update({'status': newStatus});
      
      // Cập nhật trạng thái trong state
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(status: newStatus);
        }
      });
      
      // Cập nhật trạng thái trong bloc
      context.read<TasksBloc>().add(
        UpdateTaskStatus(taskId: task.id, status: newStatus),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật trạng thái nhiệm vụ'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error updating task status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật trạng thái: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kanban - ${widget.projectName}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildKanbanBoard(),
    );
  }

  Widget _buildKanbanBoard() {
    return Container(
      height: MediaQuery.of(context).size.height - kToolbarHeight - 50,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _columns.map((column) => _buildColumn(column)).toList(),
        ),
      ),
    );
  }

  Widget _buildColumn(String columnName) {
    // Lọc các task theo trạng thái của cột
    final columnTasks = _tasks.where(
      (task) => task.status == _statusMap[columnName],
    ).toList();
    
    return Container(
      width: 280, // Width cố định cho mỗi cột
      margin: EdgeInsets.only(right: 8),
      child: Column(
        children: [
          // Tiêu đề cột
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: _columnColors[columnName],
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text(
                '$columnName (${columnTasks.length})',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Danh sách task
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DragTarget<Task>(
                builder: (context, candidateTasks, rejectedTasks) {
                  return ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: columnTasks.length,
                    itemBuilder: (context, index) => _buildTaskCard(columnTasks[index]),
                  );
                },
                onAccept: (Task task) {
                  // Cập nhật trạng thái khi kéo thả
                  _updateTaskStatus(task, _statusMap[columnName]!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    // Kiểm tra xem task có bị quá hạn không
    bool isOverdue = false;
    try {
      final parts = task.deadlineDate.split('/');
      if (parts.length == 3) {
        final deadlineDate = DateTime(
          int.parse(parts[2]), // năm
          int.parse(parts[1]), // tháng
          int.parse(parts[0]), // ngày
        );
        isOverdue = deadlineDate.isBefore(DateTime.now()) && 
                    task.status != 'completed';
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    
    // Tạo màu ưu tiên
    Color priorityColor;
    switch (task.priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.orange;
        break;
      case 'urgent':
        priorityColor = Colors.red;
        break;
      case 'low':
        priorityColor = Colors.blue;
        break;
      default:
        priorityColor = Colors.green;
    }
    
    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.28,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildTaskCardContent(task, isOverdue, priorityColor),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(task: task),
            ),
          );
        },
        child: _buildTaskCardContent(task, isOverdue, priorityColor),
      ),
    );
  }

  Widget _buildTaskCardContent(Task task, bool isOverdue, Color priorityColor) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isOverdue ? Colors.red : Colors.transparent,
          width: isOverdue ? 1 : 0,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề và ưu tiên
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Deadline
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: isOverdue ? Colors.red : Colors.grey,
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    task.deadlineDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Thành viên
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 12,
                  color: Colors.grey,
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${task.members.length} thành viên',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
