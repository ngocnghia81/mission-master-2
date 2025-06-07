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
    setState(() {
      _isLoading = true;
    });
    
    try {
      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
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
      
      // Cập nhật từng thông báo
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('Notifications')
            .where('receiveTo', isEqualTo: Auth.auth.currentUser!.email)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            // Sắp xếp thông báo theo timestamp (mới nhất trước)
            List<DocumentSnapshot> sortedDocs = List.from(snapshot.data!.docs);
            sortedDocs.sort((a, b) {
              Map<String, dynamic>? dataA = a.data() as Map<String, dynamic>?;
              Map<String, dynamic>? dataB = b.data() as Map<String, dynamic>?;
              
              Timestamp? timestampA = dataA?['timestamp'] as Timestamp?;
              Timestamp? timestampB = dataB?['timestamp'] as Timestamp?;
              
              // Nếu cả hai đều có timestamp, so sánh
              if (timestampA != null && timestampB != null) {
                return timestampB.compareTo(timestampA);
              }
              
              // Nếu chỉ có một cái có timestamp, cái có timestamp sẽ được ưu tiên
              if (timestampA != null && timestampB == null) return -1;
              if (timestampA == null && timestampB != null) return 1;
              
              // Nếu cả hai đều không có timestamp, sắp xếp theo receiveDate
              String? dateA = dataA?['receiveDate'] as String?;
              String? dateB = dataB?['receiveDate'] as String?;
              
              if (dateA != null && dateB != null) {
                return dateB.compareTo(dateA);
              }
              
              return 0;
            });
            
            return sortedDocs.isNotEmpty &&
                    snapshot.connectionState == ConnectionState.active
                ? ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: sortedDocs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot doc = sortedDocs[index];
                            // Kiểm tra trạng thái đã đọc với null safety
                            bool isRead = doc.data() is Map<String, dynamic> 
                                ? (doc.data() as Map<String, dynamic>)['isRead'] ?? false 
                                : false;
                            
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                if (index == 0 || _formatDate(doc['receiveDate']) != _formatDate(sortedDocs[index - 1]['receiveDate']))
                                  Padding(
                                    padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                                    child: text(
                                      title: _formatDate(doc['receiveDate']),
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
                            child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isRead 
                                          ? Colors.grey.shade200 
                                          : AppColors.primaryColor,
                                      child: Icon(
                                        Icons.notifications,
                                        color: isRead ? Colors.grey : Colors.white,
                                      ),
                                    ),
                              title: text(
                                title: doc['title'],
                                fontSize: size.width * 0.04,
                                      fontWeight: isRead ? AppFonts.normal : AppFonts.bold,
                                color: AppColors.black,
                                align: TextAlign.start
                              ),
                              subtitle: text(
                                title: doc['body'],
                                fontSize: size.width * 0.03,
                                      fontWeight: AppFonts.normal,
                                color: AppColors.grey,
                                align: TextAlign.start
                              ),
                                    trailing: !isRead 
                                        ? IconButton(
                                            icon: Icon(Icons.check_circle_outline),
                                            color: AppColors.primaryColor,
                                            onPressed: () => _markAsRead(doc.id),
                                            tooltip: 'Đánh dấu đã đọc',
                                          )
                                        : null,
                                    onTap: () {
                                      if (!isRead) {
                                        _markAsRead(doc.id);
                                      }
                                    },
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              text(
                      title: ViLabels.noNotifications,
                      align: TextAlign.center,
                      color: AppColors.grey,
                      fontSize: size.width * 0.045,
                      fontWeight: AppFonts.semiBold,
                              ),
                            ],
                    ),
                  );
          }
        }),
    );
  }
}
