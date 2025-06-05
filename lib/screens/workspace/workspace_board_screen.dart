import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';
import 'package:timeago/timeago.dart' as timeago;

class WorkspaceBoardScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const WorkspaceBoardScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  _WorkspaceBoardScreenState createState() => _WorkspaceBoardScreenState();
}

class _WorkspaceBoardScreenState extends State<WorkspaceBoardScreen> {
  final TextEditingController _announcementController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final _database = locator<Database>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Cấu hình localization timeago tiếng Việt
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    
    // Đảm bảo collection board tồn tại cho dự án
    _initBoardCollection();
  }
  
  Future<void> _initBoardCollection() async {
    try {
      await FirebaseFirestore.instance
          .collection('Boards')
          .doc(widget.projectId)
          .set({
            'projectId': widget.projectId,
            'projectName': widget.projectName,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Lỗi khởi tạo bảng thông báo: $e');
    }
  }
  
  @override
  void dispose() {
    _announcementController.dispose();
    _titleController.dispose();
    super.dispose();
  }
  
  // Đăng thông báo mới
  void _postAnnouncement() async {
    if (_titleController.text.trim().isEmpty || 
        _announcementController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập tiêu đề và nội dung thông báo')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = Auth.auth.currentUser!;
      
      await FirebaseFirestore.instance
          .collection('Boards')
          .doc(widget.projectId)
          .collection('announcements')
          .add({
            'title': _titleController.text.trim(),
            'content': _announcementController.text.trim(),
            'author': currentUser.displayName ?? currentUser.email,
            'authorEmail': currentUser.email,
            'authorPhotoUrl': currentUser.photoURL,
            'timestamp': FieldValue.serverTimestamp(),
            'pinned': false,
          });
      
      // Cập nhật timestamp cuối cùng của bảng thông báo
      await FirebaseFirestore.instance
          .collection('Boards')
          .doc(widget.projectId)
          .update({
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      _titleController.clear();
      _announcementController.clear();
      
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thông báo đã được đăng')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra khi đăng thông báo: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Ghim/bỏ ghim thông báo
  Future<void> _togglePinAnnouncement(String announcementId, bool currentValue) async {
    try {
      await FirebaseFirestore.instance
          .collection('Boards')
          .doc(widget.projectId)
          .collection('announcements')
          .doc(announcementId)
          .update({
            'pinned': !currentValue,
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentValue ? 'Đã bỏ ghim thông báo' : 'Đã ghim thông báo')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra: $e')),
      );
    }
  }
  
  // Xóa thông báo
  Future<void> _deleteAnnouncement(String announcementId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Boards')
          .doc(widget.projectId)
          .collection('announcements')
          .doc(announcementId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa thông báo')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Có lỗi xảy ra khi xóa thông báo: $e')),
      );
    }
  }
  
  // Hiển thị dialog tạo thông báo mới
  void _showNewAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thông báo mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _announcementController,
                decoration: InputDecoration(
                  hintText: 'Nội dung thông báo',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _postAnnouncement,
            child: _isLoading 
                ? SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Đăng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Bảng thông báo - ${widget.projectName}'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Boards')
            .doc(widget.projectId)
            .collection('announcements')
            .orderBy('pinned', descending: true)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Có lỗi xảy ra khi tải thông báo'));
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.announcement_outlined, 
                    size: 64, 
                    color: Colors.grey[400]
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có thông báo nào',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tạo thông báo đầu tiên cho dự án!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }
          
          final announcements = snapshot.data!.docs;
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              final data = announcement.data() as Map<String, dynamic>;
              final isCurrentUser = data['authorEmail'] == Auth.auth.currentUser!.email;
              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              final isPinned = data['pinned'] ?? false;
              
              return Card(
                margin: EdgeInsets.only(bottom: 16),
                elevation: isPinned ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isPinned 
                      ? BorderSide(color: theme.colorScheme.primary, width: 2) 
                      : BorderSide.none,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPinned 
                            ? theme.colorScheme.primaryContainer 
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryColor,
                            backgroundImage: data['authorPhotoUrl'] != null 
                                ? NetworkImage(data['authorPhotoUrl']) 
                                : null,
                            child: data['authorPhotoUrl'] == null 
                                ? Text(
                                    (data['author'] as String).substring(0, 1).toUpperCase(),
                                    style: TextStyle(color: Colors.white),
                                  ) 
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['author'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  timeago.format(date, locale: 'vi'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPinned)
                            Icon(
                              Icons.push_pin,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          if (isCurrentUser)
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'pin',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(isPinned ? 'Bỏ ghim' : 'Ghim'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Xóa', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'pin') {
                                  _togglePinAnnouncement(announcement.id, isPinned);
                                } else if (value == 'delete') {
                                  _deleteAnnouncement(announcement.id);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            data['content'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewAnnouncementDialog,
        backgroundColor: AppColors.accentColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
} 