import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/events.dart';

import 'package:mission_master/routes/routes.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  var project = locator<Database>;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Khởi tạo kênh thông báo
  AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'Thông báo quan trọng', // title
    description: 'Kênh thông báo dành cho các thông báo quan trọng', // description
    importance: Importance.max,
  );

  // Hàm chuyển đến tab thông báo thay vì navigate route
  void _navigateToNotificationTab(BuildContext context) {
    try {
      // Thử tìm NavBarBloc trong context
      final navBarBloc = context.read<NavBarBloc>();
      navBarBloc.add(currentPage(index: 3)); // Tab thông báo là index 3
    } catch (e) {
      print('Không thể chuyển tab thông báo: $e');
      // Fallback: sử dụng navigation route
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.main, 
        (route) => false
      );
      // Sau đó chuyển tab (có thể cần delay nhỏ)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final navBarBloc = context.read<NavBarBloc>();
          navBarBloc.add(currentPage(index: 3));
        } catch (e) {
          print('Không thể chuyển tab sau khi navigate: $e');
        }
      });
    }
  }

  // Hàm này nên được gọi sớm trong vòng đời ứng dụng
  Future<void> initializeNotifications(BuildContext context) async {
    // Yêu cầu quyền
    await requestPermission();
    
    // Thiết lập thông báo cục bộ
    await _setupLocalNotifications(context);
    
    // Thiết lập lắng nghe thông báo Firebase
    firebaseinit(context);
    
    // Xử lý tương tác với thông báo
    await setupInteractMessage(context);
    
    // Lắng nghe thay đổi token
    isTokenRefresh();
    
    // Sửa các thông báo thiếu trường isRead
    await fixMissingIsReadField();
    
    // Đăng ký nhận thông báo chung
    await subscribeToTopics();
  }

  // Thiết lập thông báo cục bộ
  Future<void> _setupLocalNotifications(BuildContext context) async {
    // Tạo kênh thông báo cho Android
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Cấu hình cho Android
    var androidInitializationSettings = const AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Cấu hình cho iOS
    var iosInitializationSettings = const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Cấu hình chung
    var initializedSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    // Khởi tạo plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializedSettings,
      onDidReceiveNotificationResponse: (payload) {
        // Chuyển đến tab thông báo thay vì route
        _navigateToNotificationTab(context);
        
        // Lưu thông báo nếu có
        if (payload.payload != null) {
          Map<String, dynamic> data = json.decode(payload.payload!);
          project().saveNotifications(
            title: data['title'],
            body: data['body'],
          );
        }
      },
    );
  }

  // Hiển thị thông báo từ Firebase
  Future<void> showNotifications(RemoteMessage message) async {
    // Hiển thị thông báo sử dụng kênh đã thiết lập
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
    );
    
    // Cấu hình cho iOS
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true);

    // Tạo chi tiết thông báo
    NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails, iOS: darwinNotificationDetails);
    
    // Hiển thị thông báo
    Future.delayed(Duration.zero, () {
      flutterLocalNotificationsPlugin.show(
        Random().nextInt(100000), // ID ngẫu nhiên để tránh ghi đè
        message.notification!.title.toString(),
        message.notification!.body.toString(),
        notificationDetails,
        payload: json.encode({
          'title': message.notification!.title,
          'body': message.notification!.body,
        }),
      );
    });
  }

  // Yêu cầu quyền thông báo
  Future<void> requestPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Người dùng đã cấp quyền thông báo: ${settings.authorizationStatus}');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('Người dùng đã cấp quyền tạm thời: ${settings.authorizationStatus}');
    } else {
      print("Người dùng từ chối quyền thông báo");
      // Mở cài đặt ứng dụng để người dùng có thể thay đổi quyền
      AppSettings.openAppSettings();
    }
  }

  // Lấy token thiết bị
  Future<String> getDeviceToken() async {
    String? token = await messaging.getToken();
    print("Device Token: $token");
    return token ?? '';
  }

  // Lắng nghe thay đổi token
  void isTokenRefresh() {
    messaging.onTokenRefresh.listen((newToken) {
      print("Token được làm mới: $newToken");
      // Ở đây bạn có thể cập nhật token mới vào cơ sở dữ liệu
    });
  }

  // Lắng nghe thông báo từ Firebase
  void firebaseinit(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Lưu thông báo vào Firestore
      if (message.notification != null) {
        project().saveNotifications(
          title: message.notification!.title.toString(),
          body: message.notification!.body.toString(),
        );
        
        // Hiển thị thông báo cục bộ
        showNotifications(message);
        
        print("Đã nhận thông báo: ${message.notification!.title}");
        print("Nội dung: ${message.notification!.body}");
      }
    });
  }

  // Xử lý khi nhấn vào thông báo
  void handleMessage(BuildContext context, RemoteMessage message) {
    if (message.notification != null) {
      // Chuyển đến tab thông báo thay vì route
      _navigateToNotificationTab(context);
    }
  }

  // Xử lý tương tác với thông báo khi ứng dụng ở background/terminated
  Future<void> setupInteractMessage(BuildContext context) async {
    // Xử lý khi ứng dụng được mở từ trạng thái terminated
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      handleMessage(context, initialMessage);
    }

    // Xử lý khi ứng dụng ở trạng thái background
    FirebaseMessaging.onMessageOpenedApp.listen((event) {
      handleMessage(context, event);
    });
  }

  // Gửi thông báo trực tiếp đến người dùng
  Future<void> sendTaskAssignmentNotification({
    required String taskName,
    required String projectName,
    required String deadline,
    required List<String> members,
  }) async {
    try {
      // Kiểm tra email người dùng hiện tại
      final currentUserEmail = Auth.auth.currentUser?.email;
      print('Đang gửi thông báo cho nhiệm vụ: $taskName');
      print('Dự án: $projectName');
      print('Deadline: $deadline');
      print('Danh sách thành viên: $members');
      print('Email người dùng hiện tại: $currentUserEmail');
      
      // Lưu thông báo vào Firestore cho mỗi thành viên
      DateTime today = DateTime.now();
      String currentDate = "${today.day}/${today.month}/${today.year}";
      
      // Danh sách email đã chuẩn hóa để gửi thông báo FCM
      List<String> normalizedEmails = [];
      
      for (String member in members) {
        print('Đang tạo thông báo cho thành viên: $member');
        
        // Đảm bảo email được chuẩn hóa (viết thường, loại bỏ khoảng trắng)
        String normalizedEmail = member.trim().toLowerCase();
        normalizedEmails.add(normalizedEmail);
        
        try {
          // Lưu thông báo vào Firestore
          await Database.firestore.collection('Notifications').doc().set({
            'title': 'Công việc mới trong $projectName',
            'body': 'Bạn đã được giao công việc: $taskName. Hạn chót: $deadline',
            'receiveDate': currentDate,
            'receiveTo': normalizedEmail,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
            'taskName': taskName,
            'projectName': projectName,
            'deadline': deadline,
          });
          
          print('Đã lưu thông báo cho: $normalizedEmail');
          
          // Hiển thị thông báo cục bộ nếu người dùng là người được giao việc
          if (currentUserEmail != null && currentUserEmail.trim().toLowerCase() == normalizedEmail) {
            print('Hiển thị thông báo cục bộ cho người dùng hiện tại: $currentUserEmail');
            await showLocalNotification(
              title: 'Công việc mới trong $projectName',
              body: 'Bạn đã được giao công việc: $taskName. Hạn chót: $deadline',
            );
          }
        } catch (e) {
          print('Lỗi khi tạo thông báo cho $normalizedEmail: $e');
        }
      }
      
      // Gửi thông báo FCM đến tất cả người dùng
      if (normalizedEmails.isNotEmpty) {
        print('Gửi thông báo FCM đến tất cả thành viên...');
        await sendPushNotificationToUsers(
          title: 'Công việc mới trong $projectName',
          body: 'Bạn đã được giao công việc: $taskName. Hạn chót: $deadline',
          userEmails: normalizedEmails,
        );
      }
      
      print('Đã gửi tất cả thông báo nhiệm vụ thành công');
    } catch (e) {
      print('Lỗi khi gửi thông báo nhiệm vụ: $e');
    }
  }

  // Gửi thông báo FCM qua Firebase Cloud Messaging
  Future<void> sendFCM({required String projectName}) async {
    try {
      // Hiển thị thông báo cục bộ
      await showLocalNotification(
        title: 'Nhắc nhở hạn chót công việc',
        body: 'Bạn có một công việc đến hạn hôm nay trong dự án: $projectName',
      );
      
      // Lưu thông báo vào Firestore
      await project().saveNotifications(
        title: 'Nhắc nhở hạn chót công việc',
        body: 'Bạn có một công việc đến hạn hôm nay trong dự án: $projectName',
      );
      
      print('Đã gửi thông báo nhắc nhở cho dự án: $projectName');
    } catch (e) {
      print('Lỗi khi gửi thông báo: $e');
    }
  }
  
  // Hiển thị thông báo cục bộ
  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    try {
      print('Đang hiển thị thông báo cục bộ: $title');
      print('Nội dung: $body');
      
      // Tạo chi tiết thông báo Android
      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
      );
      
      // Chi tiết thông báo iOS
      const DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
              presentAlert: true, presentBadge: true, presentSound: true);
      
      // Kết hợp cả hai nền tảng
      NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails, iOS: darwinNotificationDetails);
      
      // Hiển thị thông báo với ID ngẫu nhiên
      int notificationId = Random.secure().nextInt(100000);
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: json.encode({'title': title, 'body': body}),
      );
      
      print('Đã hiển thị thông báo cục bộ với ID: $notificationId');
      
      // Lưu thông báo vào Firestore
      await project().saveNotifications(title: title, body: body);
      print('Đã lưu thông báo vào Firestore');
    } catch (e) {
      print('Lỗi khi hiển thị thông báo cục bộ: $e');
    }
  }

  // Sửa các thông báo thiếu trường isRead và timestamp
  Future<void> fixMissingIsReadField() async {
    try {
      User? currentUser = Auth.auth.currentUser;
      if (currentUser == null) return;

      // Lấy tất cả thông báo của người dùng hiện tại
      QuerySnapshot notifications = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('receiveTo', isEqualTo: currentUser.email)
          .get();

      int fixedCount = 0;
      
      for (DocumentSnapshot doc in notifications.docs) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          Map<String, dynamic> updates = {};
          
          // Kiểm tra và thêm trường isRead nếu thiếu
          if (!data.containsKey('isRead')) {
            updates['isRead'] = true; // Đánh dấu các thông báo cũ là đã đọc
            fixedCount++;
          }
          
          // Kiểm tra và thêm trường timestamp nếu thiếu
          if (!data.containsKey('timestamp')) {
            updates['timestamp'] = FieldValue.serverTimestamp();
          }
          
          // Chỉ cập nhật nếu có thay đổi
          if (updates.isNotEmpty) {
            await doc.reference.update(updates);
          }
        }
      }

      if (fixedCount > 0) {
        print("Đã sửa $fixedCount thông báo thiếu trường isRead và timestamp");
      }
    } catch (e) {
      print("Lỗi khi sửa thông báo thiếu trường isRead và timestamp: $e");
    }
  }

  // Đăng ký nhận thông báo theo chủ đề
  Future<void> subscribeToTopics() async {
    try {
      // Đăng ký nhận thông báo chung cho tất cả người dùng
      await FirebaseMessaging.instance.subscribeToTopic('all_users');
      
      // Đăng ký nhận thông báo theo email người dùng (loại bỏ ký tự đặc biệt)
      if (Auth.auth.currentUser?.email != null) {
        String userEmail = Auth.auth.currentUser!.email!;
        String sanitizedEmail = userEmail.replaceAll(RegExp(r'[@.]'), '_');
        await FirebaseMessaging.instance.subscribeToTopic(sanitizedEmail);
        print('Đã đăng ký nhận thông báo cho: $sanitizedEmail');
      }
      
      print('Đã đăng ký nhận thông báo thành công');
    } catch (e) {
      print('Lỗi khi đăng ký nhận thông báo: $e');
    }
  }

  // Gửi thông báo FCM đến người dùng cụ thể
  Future<void> sendPushNotificationToUsers({
    required String title,
    required String body,
    required List<String> userEmails,
  }) async {
    try {
      print('Đang gửi thông báo FCM đến: $userEmails');
      print('Tiêu đề: $title');
      print('Nội dung: $body');

      // Chuyển đổi email thành các chủ đề FCM (topic)
      for (String email in userEmails) {
        // Chuẩn hóa email
        String normalizedEmail = email.trim().toLowerCase();
        // Chuyển đổi email thành topic FCM
        String topicName = normalizedEmail.replaceAll(RegExp(r'[@.]'), '_');
        
        print('Gửi thông báo đến topic: $topicName');
        
        // Gửi thông báo đến chủ đề tương ứng với email
        try {
          // Không gửi thông báo trực tiếp từ client, thay vào đó lưu vào Firestore
          // để cloud function có thể xử lý và gửi
          await FirebaseFirestore.instance.collection('FCMNotifications').doc().set({
            'title': title,
            'body': body,
            'topic': topicName,
            'timestamp': FieldValue.serverTimestamp(),
            'sentBy': Auth.auth.currentUser?.email ?? 'unknown',
            'processed': false, // Trường này để đánh dấu thông báo đã được xử lý hay chưa
          });
          
          print('Đã lưu thông báo FCM để gửi đến: $topicName');
        } catch (e) {
          print('Lỗi khi gửi thông báo FCM đến $topicName: $e');
        }
      }
    } catch (e) {
      print('Lỗi khi gửi thông báo FCM: $e');
    }
  }
}
