import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';
import 'package:timeago/timeago.dart' as timeago;

class WorkspaceChatScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const WorkspaceChatScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  _WorkspaceChatScreenState createState() => _WorkspaceChatScreenState();
}

class _WorkspaceChatScreenState extends State<WorkspaceChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _database = locator<Database>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Cấu hình localization timeago tiếng Việt
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    
    // Đảm bảo collection chat tồn tại cho dự án
    _initChatCollection();
  }
  
  Future<void> _initChatCollection() async {
    try {
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(widget.projectId)
          .set({
            'projectId': widget.projectId,
            'projectName': widget.projectName,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Lỗi khởi tạo chat: $e');
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Gửi tin nhắn mới
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = Auth.auth.currentUser!;
      
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(widget.projectId)
          .collection('messages')
          .add({
            'text': _messageController.text.trim(),
            'sender': currentUser.displayName ?? currentUser.email,
            'senderEmail': currentUser.email,
            'senderPhotoUrl': currentUser.photoURL,
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      // Cập nhật timestamp cuối cùng của chat
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(widget.projectId)
          .update({
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      
      _messageController.clear();
      
      // Cuộn xuống cuối danh sách tin nhắn
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
        SnackBar(content: Text('Có lỗi xảy ra khi gửi tin nhắn: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${widget.projectName}'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          // Tin nhắn
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Chats')
                  .doc(widget.projectId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Có lỗi xảy ra khi tải tin nhắn'));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline, 
                          size: 64, 
                          color: Colors.grey[400]
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có tin nhắn nào',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Hãy gửi tin nhắn đầu tiên!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final messages = snapshot.data!.docs;
                
                // Tự động cuộn xuống dưới khi có tin nhắn mới
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isCurrentUser = message['senderEmail'] == Auth.auth.currentUser!.email;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate() ?? DateTime.now();
                    
                    return _buildMessageBubble(
                      sender: message['sender'] ?? 'Unknown',
                      text: message['text'] ?? '',
                      time: date,
                      photoUrl: message['senderPhotoUrl'],
                      isCurrentUser: isCurrentUser,
                    );
                  },
                );
              },
            ),
          ),
          
          // Input tin nhắn
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
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
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
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: _isLoading 
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send),
                  color: theme.colorScheme.primary,
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble({
    required String sender,
    required String text,
    required DateTime time,
    String? photoUrl,
    required bool isCurrentUser,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isCurrentUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryColor,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null 
                  ? Text(
                      sender.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ) 
                  : null,
            ),
            SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Text(
                      sender,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  
                  SizedBox(height: isCurrentUser ? 0 : 4),
                  
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  
                  SizedBox(height: 4),
                  
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeago.format(time, locale: 'vi'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryColor,
              backgroundImage: Auth.auth.currentUser!.photoURL != null 
                  ? NetworkImage(Auth.auth.currentUser!.photoURL!) 
                  : null,
              child: Auth.auth.currentUser!.photoURL == null 
                  ? Text(
                      Auth.auth.currentUser!.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ) 
                  : null,
            ),
          ],
        ],
      ),
    );
  }
} 