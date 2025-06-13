import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/notification/notification_services.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:app_settings/app_settings.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  final _database = locator<Database>();
  final notificationServices = NotificationServices();
  bool _isLoading = false;
  
  // Đánh dấu thông báo đã đọc
  Future<void> _markAsRead(String notificationId) async {
    print('Đánh dấu thông báo đã đọc: $notificationId');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Kiểm tra xem thông báo có tồn tại không
      DocumentSnapshot notificationDoc = await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notificationId)
          .get();
          
      if (!notificationDoc.exists) {
        print('Thông báo không tồn tại: $notificationId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tìm thấy thông báo'), backgroundColor: Colors.red),
        );
        return;
      }
      
      print('Đang cập nhật trạng thái đã đọc cho thông báo: $notificationId');
      
      // Cập nhật trạng thái đã đọc
      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notificationId)
          .update({'isRead': true});
          
      print('Đã cập nhật trạng thái đã đọc thành công cho thông báo: $notificationId');
      
      // Kiểm tra xem cập nhật có thành công không
      DocumentSnapshot updatedDoc = await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notificationId)
          .get();
          
      Map<String, dynamic> data = updatedDoc.data() as Map<String, dynamic>;
      bool isRead = data['isRead'] ?? false;
      
      print('Trạng thái đã đọc sau khi cập nhật: $isRead');
      
      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đánh dấu thông báo là đã đọc'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      
      // Cập nhật giao diện
      setState(() {});
    } catch (e) {
      print('Lỗi khi đánh dấu thông báo đã đọc: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
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
  
  // Đánh dấu tất cả thông báo đã đọc
  Future<void> _markAllAsRead() async {
    print('Đánh dấu tất cả thông báo đã đọc');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Lấy tất cả thông báo chưa đọc
      final snapshot = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('receiveTo', isEqualTo: Auth.auth.currentUser!.email)
          .where('isRead', isEqualTo: false)
          .get();
      
      print('Số lượng thông báo chưa đọc: ${snapshot.docs.length}');
      
      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không có thông báo chưa đọc'),
            backgroundColor: Colors.blue,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Cập nhật từng thông báo
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        print('Đánh dấu thông báo đã đọc: ${doc.id}');
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      
      print('Đã đánh dấu ${snapshot.docs.length} thông báo là đã đọc');
      
      // Kiểm tra xem cập nhật có thành công không
      int successCount = 0;
      for (var doc in snapshot.docs) {
        DocumentSnapshot updatedDoc = await FirebaseFirestore.instance
            .collection('Notifications')
            .doc(doc.id)
            .get();
            
        Map<String, dynamic> data = updatedDoc.data() as Map<String, dynamic>;
        bool isRead = data['isRead'] ?? false;
        
        if (isRead) {
          successCount++;
        }
      }
      
      print('Số thông báo đã được cập nhật thành công: $successCount/${snapshot.docs.length}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đánh dấu $successCount thông báo là đã đọc'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Cập nhật giao diện
      setState(() {});
    } catch (e) {
      print('Lỗi khi đánh dấu tất cả thông báo là đã đọc: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
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
  
  // Kiểm tra kết nối FCM
  Future<void> _checkFCMConnection() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await notificationServices.checkFCMConnection();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result 
            ? 'Kết nối FCM hoạt động tốt! Đã gửi thông báo kiểm tra.' 
            : 'Có vấn đề với kết nối FCM. Vui lòng kiểm tra quyền thông báo.'),
          backgroundColor: result ? Colors.green : Colors.orange,
          duration: Duration(seconds: 5),
          action: result ? null : SnackBarAction(
            label: 'Cài đặt',
            onPressed: () {
              AppSettings.openAppSettings();
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi kiểm tra kết nối FCM: $e'),
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

  // Format thời gian thông báo
  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        
        final date = DateTime(year, month, day);
        final now = DateTime.now();
        
        // Nếu là ngày hôm nay
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          return 'Hôm nay';
        }
        
        // Nếu là ngày hôm qua
        final yesterday = now.subtract(Duration(days: 1));
        if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
          return 'Hôm qua';
        }
        
        // Các ngày khác
        return DateFormat('dd/MM/yyyy').format(date);
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  // Lấy biểu tượng thông báo dựa vào nội dung
  Widget _getNotificationIcon(DocumentSnapshot doc, bool isRead) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Kiểm tra loại thông báo
    if (data.containsKey('assignedBy') && data['assignedBy'] != null) {
      // Thông báo giao nhiệm vụ
      return CircleAvatar(
        backgroundColor: isRead ? Colors.grey.shade200 : Colors.orange,
        child: Icon(
          Icons.assignment,
          color: isRead ? Colors.grey : Colors.white,
        ),
      );
    } else if (data.containsKey('updatedBy') && data['updatedBy'] != null) {
      // Thông báo cập nhật trạng thái
      return CircleAvatar(
        backgroundColor: isRead ? Colors.grey.shade200 : Colors.green,
        child: Icon(
          Icons.update,
          color: isRead ? Colors.grey : Colors.white,
        ),
      );
    } else {
      // Thông báo thông thường
      return CircleAvatar(
        backgroundColor: isRead ? Colors.grey.shade200 : AppColors.primaryColor,
        child: Icon(
          Icons.notifications,
          color: isRead ? Colors.grey : Colors.white,
        ),
      );
    }
  }

  // Lấy thông tin người gửi thông báo
  Widget _getSenderInfo(DocumentSnapshot doc, double fontSize) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Kiểm tra loại thông báo
    if (data.containsKey('assignedBy') && data['assignedBy'] != null) {
      // Thông báo giao nhiệm vụ
      return Row(
        children: [
          Icon(Icons.person_outline, size: fontSize * 0.9, color: AppColors.grey),
          SizedBox(width: 4),
          text(
            title: "Người giao: ${data['assignedBy']}",
            fontSize: fontSize * 0.7,
            fontWeight: AppFonts.normal,
            color: AppColors.grey,
            align: TextAlign.start
          ),
        ],
      );
    } else if (data.containsKey('updatedBy') && data['updatedBy'] != null) {
      // Thông báo cập nhật trạng thái
      return Row(
        children: [
          Icon(Icons.person_outline, size: fontSize * 0.9, color: AppColors.grey),
          SizedBox(width: 4),
          text(
            title: "Cập nhật bởi: ${data['updatedBy']}",
            fontSize: fontSize * 0.7,
            fontWeight: AppFonts.normal,
            color: AppColors.grey,
            align: TextAlign.start
          ),
        ],
      );
    } else {
      // Không có thông tin người gửi
      return Container();
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Kiểm tra kết nối FCM khi màn hình được tạo
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkFCMConnection();
      
      // Kiểm tra thông báo trong Firestore
      print('Đang kiểm tra thông báo trong Firestore...');
      final currentUserEmail = Auth.auth.currentUser?.email;
      print('Email người dùng hiện tại: $currentUserEmail');
      
      try {
        final querySnapshot = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('receiveTo', isEqualTo: currentUserEmail)
          .get();
          
        print('Số lượng thông báo tìm thấy: ${querySnapshot.docs.length}');
        
        for (var doc in querySnapshot.docs) {
          print('Thông báo ID: ${doc.id}');
          print('Tiêu đề: ${doc.data()['title']}');
          print('Người nhận: ${doc.data()['receiveTo']}');
        }
      } catch (e) {
        print('Lỗi khi truy vấn thông báo: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: text(
          title: 'Thông báo',
          fontSize: size.width * 0.05,
          fontWeight: AppFonts.semiBold,
          color: AppColors.black,
          align: TextAlign.start,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Nút đánh dấu tất cả đã đọc
          IconButton(
            icon: Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Đánh dấu tất cả đã đọc',
          ),
          // Nút làm mới
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Notifications')
                  .where('receiveTo', isEqualTo: Auth.auth.currentUser!.email)
                  .orderBy('timestamp', descending: true) // Sắp xếp theo timestamp giảm dần
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  // Xử lý lỗi
                  print('Lỗi khi tải thông báo: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        text(
                          title: 'Không thể tải thông báo',
                          fontSize: size.width * 0.05,
                          fontWeight: AppFonts.semiBold,
                          color: Colors.red,
                          align: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        text(
                          title: 'Vui lòng thử lại sau',
                          fontSize: size.width * 0.04,
                          fontWeight: AppFonts.normal,
                          color: AppColors.grey,
                          align: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: text(
                              title: 'Thử lại',
                              fontSize: size.width * 0.04,
                              fontWeight: AppFonts.medium,
                              color: Colors.white,
                              align: TextAlign.center,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // Hiển thị thông báo khi không có dữ liệu
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        text(
                          title: 'Không có thông báo nào',
                          fontSize: size.width * 0.05,
                          fontWeight: AppFonts.semiBold,
                          color: AppColors.grey,
                          align: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: text(
                              title: 'Làm mới',
                              fontSize: size.width * 0.04,
                              fontWeight: AppFonts.medium,
                              color: Colors.white,
                              align: TextAlign.center,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Lấy danh sách thông báo đã được sắp xếp từ Firestore
                  List<DocumentSnapshot> sortedDocs = List.from(snapshot.data!.docs);
                  
                  // Debug: In ra thông tin thông báo
                  print('Số lượng thông báo: ${sortedDocs.length}');
                  for (var doc in sortedDocs.take(3)) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    print('Thông báo: ${doc.id} - ${data['title']} - ${data['timestamp']} - Đã đọc: ${data['isRead'] ?? false}');
                  }
                  
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        DocumentSnapshot doc = sortedDocs[index];
                        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                        
                        // Kiểm tra trạng thái đã đọc với null safety
                        bool isRead = data['isRead'] ?? false;
                        
                        // Xác định ngày nhận
                        String receiveDate = data['receiveDate'] ?? 'Không rõ ngày';
                          
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index == 0 || _formatDate(receiveDate) != _formatDate(sortedDocs[index - 1].data() is Map<String, dynamic> ? (sortedDocs[index - 1].data() as Map<String, dynamic>)['receiveDate'] ?? '' : ''))
                              Padding(
                                padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                                child: text(
                                  title: _formatDate(receiveDate),
                                  fontSize: size.width * 0.04,
                                  fontWeight: AppFonts.semiBold,
                                  color: AppColors.grey,
                                  align: TextAlign.start
                                ),
                              ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                vertical: size.height * 0.01,
                              ),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.white : Colors.blue.shade50,
                                border: Border.all(
                                  width: 1, 
                                  color: isRead ? Colors.grey : Colors.blue.shade300),
                                borderRadius: BorderRadius.circular(10.0),
                                boxShadow: isRead 
                                  ? [] 
                                  : [BoxShadow(
                                      color: Colors.blue.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    leading: _getNotificationIcon(doc, isRead),
                                    title: text(
                                      title: data['title'] ?? 'Không có tiêu đề',
                                      fontSize: size.width * 0.04,
                                      fontWeight: isRead ? AppFonts.normal : AppFonts.bold,
                                      color: AppColors.black,
                                      align: TextAlign.start
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        text(
                                          title: data['body'] ?? 'Không có nội dung',
                                          fontSize: size.width * 0.03,
                                          fontWeight: AppFonts.normal,
                                          color: AppColors.grey,
                                          align: TextAlign.start
                                        ),
                                        SizedBox(height: 4),
                                        // Hiển thị thông tin người gửi (người giao hoặc người cập nhật)
                                        _getSenderInfo(doc, size.width * 0.035),
                                        // Kiểm tra null safety cho trường deadline
                                        if (data.containsKey('deadline') && data['deadline'] != null) 
                                          SizedBox(height: 4),
                                        if (data.containsKey('deadline') && data['deadline'] != null)
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, 
                                                size: size.width * 0.035, 
                                                color: AppColors.grey),
                                              SizedBox(width: 4),
                                              text(
                                                title: "Hạn chót: ${data['deadline']}",
                                                fontSize: size.width * 0.025,
                                                fontWeight: AppFonts.normal,
                                                color: AppColors.grey,
                                                align: TextAlign.start
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    trailing: !isRead 
                                        ? IconButton(
                                            icon: Icon(Icons.check_circle_outline),
                                            color: AppColors.primaryColor,
                                            onPressed: () => _markAsRead(doc.id),
                                            tooltip: 'Đánh dấu đã đọc',
                                          )
                                        : Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    onTap: () {
                                      if (!isRead) {
                                        _markAsRead(doc.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }
              },
            ),
      floatingActionButton: IconButton(
        icon: Icon(Icons.refresh),
        onPressed: () => setState(() {}),
        tooltip: 'Làm mới',
      ),
    );
  }
}
