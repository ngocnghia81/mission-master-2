import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:timeago/timeago.dart' as timeago;

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _database = locator<Database>();
  bool _isLoading = false;
  String _currentStatus = 'none';
  
  @override
  void initState() {
    super.initState();
    _currentStatus = widget.task.status;
    
    // Cấu hình localization timeago tiếng Việt
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    
    // Kiểm tra nếu task đã quá hạn
    _checkIfTaskOverdue();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Kiểm tra task có bị quá hạn không
  void _checkIfTaskOverdue() {
    try {
      final dateFormat = widget.task.deadlineDate.split('/');
      if (dateFormat.length == 3) {
        final deadline = DateTime(
          int.parse(dateFormat[2]), 
          int.parse(dateFormat[1]), 
          int.parse(dateFormat[0])
        );
        
        final isOverdue = DateTime.now().isAfter(deadline) && _currentStatus != 'completed';
        
        if (isOverdue) {
          // Hiển thị thông báo nếu task quá hạn và chưa hoàn thành
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Task này đã quá hạn! Vui lòng cập nhật trạng thái hoặc liên hệ với quản lý dự án.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Đóng',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      print('Lỗi khi kiểm tra hạn chót: $e');
    }
  }

  // Gửi bình luận mới
  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _database.addComments(
        id: widget.task.id,
        comment: _commentController.text.trim(),
      );
      
      _commentController.clear();
      
      // Cuộn xuống cuối danh sách bình luận
      if (_scrollController.hasClients) {
        Future.delayed(Duration(milliseconds: 300), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Cập nhật trạng thái công việc
  Future<void> _updateTaskStatus(String newStatus) async {
    // Kiểm tra xem người dùng hiện tại có quyền cập nhật trạng thái không
    if (!_isCurrentUserAssigned()) {
      _showErrorMessage('Bạn không có quyền cập nhật trạng thái task này. Chỉ người được giao task mới có thể cập nhật trạng thái.');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print("Đang cập nhật trạng thái task '${widget.task.title}' từ '$_currentStatus' sang '$newStatus'");
      print("Task ID: ${widget.task.id}");
      print("Project ID: ${widget.task.projectId}");
      
      // Kiểm tra nếu task ID và project ID giống nhau (lỗi dữ liệu)
      if (widget.task.id == widget.task.projectId) {
        // Thử cập nhật trạng thái chỉ bằng tên task
        print("Phát hiện lỗi: Task ID và Project ID giống nhau, thử cập nhật bằng tên task");
      bool success = await _database.updateTaskStatus(
        taskName: widget.task.title,
        changeStatusTo: newStatus,
      );
      
      if (success) {
        setState(() {
          _currentStatus = newStatus;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trạng thái đã được cập nhật thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
          _showErrorMessage('Không thể cập nhật trạng thái. Đã phát hiện lỗi trong cấu trúc dữ liệu task.');
        }
        return;
      }
      
      // Trường hợp bình thường - task ID và project ID khác nhau
      bool success = await _database.updateTaskStatus(
        taskName: widget.task.title,
        changeStatusTo: newStatus,
        taskId: widget.task.id,
        projectId: widget.task.projectId,
      );
      
      if (success) {
        setState(() {
          _currentStatus = newStatus;
        });
        
        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trạng thái đã được cập nhật thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Đợi 1 giây rồi pop màn hình để quay lại
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showErrorMessage('Không thể cập nhật trạng thái. Vui lòng thử lại.');
      }
    } catch (e) {
      print("Lỗi khi cập nhật trạng thái: $e");
      _showErrorMessage('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Hiển thị thông báo lỗi
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  // Kiểm tra xem người dùng hiện tại có phải là thành viên của task hay không
  bool _isCurrentUserAssigned() {
    return widget.task.members.contains(Auth.auth.currentUser!.email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(ViLabels.taskDetails),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : Column(
          children: [
            // Task details section
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task title
                    Text(
                      widget.task.title,
                      style: theme.textTheme.headlineMedium,
                    ),
                    SizedBox(height: 16),
                    
                    // Priority chip
                    _buildPriorityChip(),
                    SizedBox(height: 16),
                    
                    // Status indicator and update button
                    _buildStatusSection(),
                    SizedBox(height: 24),
                    
                    // Description
                    Text(
                      'Mô tả:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.task.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: 24),
                    
                    // Deadline
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: 'Hạn chót:',
                      value: '${widget.task.deadlineDate} ${widget.task.deadlineTime}',
                    ),
                    SizedBox(height: 8),
                    
                    // Project
                    _buildInfoRow(
                      icon: Icons.folder_outlined,
                      label: 'Dự án:',
                      value: widget.task.projectName,
                    ),
                    
                    // Recurring info if applicable
                    if (widget.task.isRecurring) ...[
                      SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.repeat,
                        label: 'Lặp lại:',
                        value: _getRecurringText(widget.task.recurringInterval),
                      ),
                    ],
                    
                    SizedBox(height: 24),
                    
                    // Members
                    Text(
                      'Thành viên được giao:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildMembersList(),
                    
                    SizedBox(height: 24),
                    
                    // Lịch sử cập nhật
                    _buildUpdateHistory(),
                    
                    SizedBox(height: 24),
                    
                    // Comments section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bình luận',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.chat_bubble_outline),
                      ],
                    ),
                    SizedBox(height: 8),
                    Divider(),
                  ],
                ),
              ),
            ),
            
            // Comments stream
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _database.getComments(id: widget.task.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('Có lỗi xảy ra khi tải bình luận'));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('Chưa có bình luận nào'));
                  }
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['time'] as Timestamp;
                      final date = timestamp.toDate();
                      
                      return _buildCommentBubble(
                        author: data['author'] ?? 'Unknown',
                        comment: data['comment'] ?? '',
                        time: date,
                        isCurrentUser: data['author'] == Auth.auth.currentUser!.displayName,
                      );
                    },
                  );
                },
              ),
            ),
            
            // Comment input
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Nhập bình luận...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    color: theme.colorScheme.primary,
                    onPressed: _sendComment,
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
  
  Widget _buildPriorityChip() {
    Color priorityColor = _getPriorityColor(widget.task.priority);
    String priorityText = _getPriorityText(widget.task.priority);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.2),
        border: Border.all(color: priorityColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.task.priority == 'urgent' 
                ? Icons.priority_high 
                : (widget.task.priority == 'high' 
                    ? Icons.arrow_upward 
                    : (widget.task.priority == 'low' 
                        ? Icons.arrow_downward 
                        : Icons.remove)),
            color: priorityColor,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            priorityText,
            style: TextStyle(
              color: priorityColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusSection() {
    // Kiểm tra task có quá hạn không
    bool isOverdue = false;
    try {
      final dateFormat = widget.task.deadlineDate.split('/');
      if (dateFormat.length == 3) {
        final deadline = DateTime(
          int.parse(dateFormat[2]), 
          int.parse(dateFormat[1]), 
          int.parse(dateFormat[0])
        );
        isOverdue = DateTime.now().isAfter(deadline) && _currentStatus != 'completed';
      }
    } catch (e) {
      print('Lỗi khi kiểm tra hạn chót: $e');
    }

    // Kiểm tra xem người dùng hiện tại có phải là thành viên được giao task không
    final bool isAssigned = _isCurrentUserAssigned();
    // Người tạo task được xác định bằng email đầu tiên trong danh sách thành viên
    final bool isCreator = widget.task.members.isNotEmpty && 
                          Auth.auth.currentUser != null && 
                          Auth.auth.currentUser!.email == widget.task.members.first;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trạng thái:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                // Hiển thị cảnh báo nếu quá hạn
                if (isOverdue)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Quá hạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_currentStatus),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusText(_currentStatus),
                    style: TextStyle(
                      color: _getTextColorForStatus(_currentStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            // Chỉ hiển thị nút cập nhật trạng thái nếu người dùng được giao task hoặc là người tạo task
            if (isAssigned || isCreator) ...[
              SizedBox(height: 16),
              Text(
                'Cập nhật trạng thái:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusButton(
                    status: 'none',
                    text: 'Chờ xử lý',
                    color: AppColors.taskPending,
                  ),
                  SizedBox(width: 8),
                  _buildStatusButton(
                    status: 'in progress',
                    text: 'Đang thực hiện',
                    color: AppColors.taskInProgress,
                  ),
                  SizedBox(width: 8),
                  _buildStatusButton(
                    status: 'completed',
                    text: 'Hoàn thành',
                    color: AppColors.taskCompleted,
                  ),
                ],
              ),
              // Thêm thông tin thời gian cập nhật nếu có
              if (isOverdue && _currentStatus != 'completed') ...[
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Task này đã quá hạn. Vui lòng cập nhật trạng thái hoặc liên hệ người quản lý.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            ] else ...[
              // Hiển thị thông báo nếu người dùng không được giao task
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade700, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chỉ người được giao task mới có thể cập nhật trạng thái.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusButton({
    required String status,
    required String text,
    required Color color,
  }) {
    final isSelected = _currentStatus == status;
    
    return Expanded(
      child: ElevatedButton(
        onPressed: isSelected ? null : () => _updateTaskStatus(status),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? color : color.withOpacity(0.3),
          foregroundColor: isSelected 
              ? _getTextColorForStatus(status) 
              : _getTextColorForStatus(status).withOpacity(0.7),
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMembersList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.task.members.map((member) {
        final isCurrentUser = member == Auth.auth.currentUser!.email;
        return Chip(
          label: Text(
            member,
            style: TextStyle(
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          avatar: CircleAvatar(
            backgroundColor: isCurrentUser ? AppColors.primaryColor : Colors.grey,
            child: Text(
              member.substring(0, 1).toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          backgroundColor: isCurrentUser 
              ? AppColors.primaryColor.withOpacity(0.1) 
              : Colors.grey.withOpacity(0.1),
        );
      }).toList(),
    );
  }
  
  Widget _buildCommentBubble({
    required String author,
    required String comment,
    required DateTime time,
    required bool isCurrentUser,
  }) {
    final theme = Theme.of(context);
    
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser 
              ? theme.colorScheme.primary.withOpacity(0.2) 
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentUser 
                ? theme.colorScheme.primary.withOpacity(0.5) 
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  author,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCurrentUser 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  timeago.format(time, locale: 'vi'),
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(comment),
          ],
        ),
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
  
  String _getPriorityText(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 'Khẩn cấp';
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      default:
        return 'Bình thường';
    }
  }
  
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  String _getRecurringText(String interval) {
    switch (interval.toLowerCase()) {
      case 'daily':
        return 'Hàng ngày';
      case 'weekly':
        return 'Hàng tuần';
      case 'monthly':
        return 'Hàng tháng';
      default:
        return interval;
    }
  }
  
  // Hiển thị lịch sử cập nhật task
  Widget _buildUpdateHistory() {
    // Debug: In ra thông tin ID để kiểm tra
    print('Task ID: ${widget.task.id}');
    print('Project ID: ${widget.task.projectId}');
    
    // Kiểm tra xem projectId có hợp lệ không
    final String projectId = widget.task.projectId.isNotEmpty 
        ? widget.task.projectId 
        : (widget.task.id.contains('_') ? widget.task.id.split('_').first : '');
        
    // Nếu projectId trùng với taskId, đây có thể là lỗi
    if (projectId == widget.task.id) {
      print('CẢNH BÁO: Project ID trùng với Task ID - có thể gây lỗi khi cập nhật');
      
      // Hiển thị thông báo lỗi thay vì cố gắng tải dữ liệu
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch sử cập nhật',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Không thể tải lịch sử cập nhật',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Đã phát hiện lỗi trong cấu trúc dữ liệu task. Vui lòng liên hệ quản trị viên.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chi tiết: Task ID và Project ID giống nhau',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _fixTaskIdIssue,
                    icon: Icon(Icons.build_rounded, size: 16),
                    label: Text('Sửa lỗi ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // Nếu không có lỗi, hiển thị dữ liệu bình thường
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lịch sử cập nhật',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Tasks')
              .doc(projectId)
              .collection('projectTasks')
              .doc(widget.task.id)
              .collection('statusUpdates')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            
            if (snapshot.hasError) {
              return Text('Không thể tải lịch sử cập nhật: ${snapshot.error}');
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Chưa có cập nhật nào được ghi lại',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }
            
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as Timestamp;
                final date = timestamp.toDate();
                final updatedBy = data['updatedBy'] ?? 'Unknown';
                final fromStatus = data['fromStatus'] ?? 'none';
                final toStatus = data['toStatus'] ?? 'none';
                
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.history,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$updatedBy đã cập nhật trạng thái từ "${_getStatusText(fromStatus)}" sang "${_getStatusText(toStatus)}"',
                                style: TextStyle(fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                timeago.format(date, locale: 'vi'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
  
  // Hàm sửa lỗi ID của task
  Future<void> _fixTaskIdIssue() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Tạo ID mới cho task
      final String newTaskId = '${widget.task.id}_fixed_${DateTime.now().millisecondsSinceEpoch}';
      
      // Tìm task trong Firestore
      final projectsSnap = await FirebaseFirestore.instance.collection('Tasks').get();
      bool fixed = false;
      
      for (var projectDoc in projectsSnap.docs) {
        if (projectDoc.id == widget.task.id) {
          // Tìm task trong collection projectTasks
          final tasksSnap = await projectDoc.reference
              .collection('projectTasks')
              .where('taskName', isEqualTo: widget.task.title)
              .get();
              
          if (tasksSnap.docs.isNotEmpty) {
            // Tìm thấy task, tạo bản sao với ID mới
            final taskDoc = tasksSnap.docs.first;
            final taskData = taskDoc.data();
            
            // Tạo bản sao task với ID mới
            await projectDoc.reference
                .collection('projectTasks')
                .doc(newTaskId)
                .set(taskData);
                
            // Xóa task cũ
            await taskDoc.reference.delete();
            
            // Hiển thị thông báo thành công
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã sửa lỗi ID của task thành công'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Quay lại màn hình trước
            Navigator.of(context).pop();
            fixed = true;
            break;
          }
        }
      }
      
      if (!fixed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể sửa lỗi ID của task. Vui lòng thử lại sau.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Lỗi khi sửa ID của task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 