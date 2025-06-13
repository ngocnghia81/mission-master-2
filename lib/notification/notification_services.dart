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
import 'package:permission_handler/permission_handler.dart';

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
    playSound: true,
    enableVibration: true,
    enableLights: true,
    showBadge: true,
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
    try {
      print('Bắt đầu khởi tạo hệ thống thông báo...');
      
      // Kiểm tra và yêu cầu quyền thông báo cho Android 13+
      await checkAndRequestNotificationPermission();
      print('Đã kiểm tra quyền thông báo cho Android 13+');
      
      // Yêu cầu quyền thông báo Firebase
      await requestPermission();
      print('Đã yêu cầu quyền thông báo Firebase');
      
      // Thiết lập thông báo cục bộ
      await _setupLocalNotifications(context);
      print('Đã thiết lập thông báo cục bộ');
      
      // Thiết lập lắng nghe thông báo Firebase
      firebaseinit(context);
      print('Đã thiết lập lắng nghe thông báo Firebase');
      
      // Xử lý tương tác với thông báo
      await setupInteractMessage(context);
      print('Đã thiết lập xử lý tương tác với thông báo');
      
      // Lắng nghe thay đổi token
      isTokenRefresh();
      print('Đã thiết lập lắng nghe thay đổi token');
      
      // Sửa các thông báo thiếu trường isRead
      await fixMissingIsReadField();
      print('Đã sửa các thông báo thiếu trường isRead');
      
      // Đăng ký nhận thông báo chung
      await subscribeToTopics();
      print('Đã đăng ký nhận thông báo chung');
      
      // Kiểm tra thông báo để đảm bảo mọi thứ hoạt động
      await testNotification();
      print('Đã kiểm tra hệ thống thông báo');
      
      print('Khởi tạo hệ thống thông báo hoàn tất');
    } catch (e) {
      print('Lỗi khi khởi tạo hệ thống thông báo: $e');
    }
  }

  // Kiểm tra và yêu cầu quyền thông báo cho Android 13+
  Future<void> checkAndRequestNotificationPermission() async {
    try {
      // Chỉ áp dụng cho Android
      if (!io.Platform.isAndroid) return;
      
      print('Kiểm tra quyền thông báo cho Android...');
      
      // Kiểm tra trạng thái quyền thông báo
      PermissionStatus status = await Permission.notification.status;
      print('Trạng thái quyền thông báo hiện tại: $status');
      
      // Nếu chưa được cấp quyền, yêu cầu quyền
      if (status.isDenied || status.isRestricted || status.isLimited) {
        print('Yêu cầu quyền thông báo...');
        status = await Permission.notification.request();
        print('Kết quả yêu cầu quyền thông báo: $status');
      }
      
      // Nếu người dùng từ chối vĩnh viễn, mở cài đặt ứng dụng
      if (status.isPermanentlyDenied) {
        print('Quyền thông báo bị từ chối vĩnh viễn. Mở cài đặt ứng dụng...');
        await AppSettings.openAppSettings();
      }
    } catch (e) {
      print('Lỗi khi kiểm tra và yêu cầu quyền thông báo: $e');
    }
  }

  // Thiết lập thông báo cục bộ
  Future<void> _setupLocalNotifications(BuildContext context) async {
    try {
      print('Bắt đầu thiết lập thông báo cục bộ...');
      
      // Tạo kênh thông báo cho Android
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      print('Đã tạo kênh thông báo Android: ${channel.id}');

      // Cấu hình cho Android
      var androidInitializationSettings = const AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Cấu hình cho iOS
      var iosInitializationSettings = const DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
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
          print('Đã nhận tương tác với thông báo: ${payload.payload}');
          
          // Chuyển đến tab thông báo thay vì route
          _navigateToNotificationTab(context);
          
          // Lưu thông báo nếu có
          if (payload.payload != null) {
            try {
              Map<String, dynamic> data = json.decode(payload.payload!);
              project().saveNotifications(
                title: data['title'] ?? 'Thông báo mới',
                body: data['body'] ?? '',
              );
              print('Đã lưu thông báo từ tương tác');
            } catch (e) {
              print('Lỗi khi xử lý payload thông báo: $e');
            }
          }
        },
      );
      
      print('Đã khởi tạo plugin thông báo cục bộ');
      
      // Kiểm tra các thông báo đang chờ
      final List<PendingNotificationRequest> pendingNotifications = 
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('Số thông báo đang chờ: ${pendingNotifications.length}');
    } catch (e) {
      print('Lỗi khi thiết lập thông báo cục bộ: $e');
    }
  }

  // Hiển thị thông báo từ Firebase
  Future<void> showNotifications(RemoteMessage message) async {
    try {
      print('Đang hiển thị thông báo từ Firebase: ${message.notification?.title}');
      
      // Tạo ID thông báo ngẫu nhiên để tránh ghi đè
      int notificationId = Random().nextInt(100000);
      
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
        // Thêm các tùy chọn để đảm bảo thông báo hiển thị dạng heads-up
        playSound: true,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message, // Sử dụng category message
        channelShowBadge: true,
      );
      
      // Cấu hình cho iOS
      const DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
              presentAlert: true, 
              presentBadge: true, 
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive // Tăng mức độ ưu tiên
          );

      // Tạo chi tiết thông báo
      NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails, iOS: darwinNotificationDetails);
      
      // Hiển thị thông báo ngay lập tức
      await flutterLocalNotificationsPlugin.show(
        notificationId, 
        message.notification!.title.toString(),
        message.notification!.body.toString(),
        notificationDetails,
        payload: json.encode({
          'title': message.notification!.title,
          'body': message.notification!.body,
          'data': message.data,
        }),
      );
      
      print('Đã hiển thị thông báo với ID: $notificationId');
      
      // Lưu thông báo vào Firestore
      await project().saveNotifications(
        title: message.notification!.title.toString(),
        body: message.notification!.body.toString(),
      );
      
      print('Đã lưu thông báo vào Firestore');
    } catch (e) {
      print('Lỗi khi hiển thị thông báo: $e');
    }
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
    BuildContext? context, // Thêm tham số context
  }) async {
    try {
      // Kiểm tra email người dùng hiện tại
      final currentUserEmail = Auth.auth.currentUser?.email;
      final currentUserName = Auth.auth.currentUser?.displayName ?? 'Ai đó';
      print('Đang gửi thông báo cho nhiệm vụ: $taskName');
      print('Dự án: $projectName');
      print('Deadline: $deadline');
      print('Danh sách thành viên: $members');
      print('Email người dùng hiện tại: $currentUserEmail');
      print('Tên người giao nhiệm vụ: $currentUserName');
      
      // Tạo nội dung thông báo
      final title = 'Công việc mới trong $projectName';
      final body = '$currentUserName đã giao cho bạn công việc: $taskName. Hạn chót: $deadline';
      
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
          // Tạo ID duy nhất cho thông báo
          String notificationId = 'task_notification_${DateTime.now().millisecondsSinceEpoch}_${normalizedEmail.hashCode}';
          
          // Lưu thông báo vào Firestore
          await Database.firestore.collection('Notifications').doc(notificationId).set({
            'title': title,
            'body': body,
            'receiveDate': currentDate,
            'receiveTo': normalizedEmail,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
            'taskName': taskName,
            'projectName': projectName,
            'deadline': deadline,
            'assignedBy': currentUserName,
            'assignedByEmail': currentUserEmail,
          });
          
          print('Đã lưu thông báo cho: $normalizedEmail với ID: $notificationId');
          
          // Kiểm tra xem thông báo đã được lưu thành công chưa
          DocumentSnapshot checkDoc = await Database.firestore.collection('Notifications').doc(notificationId).get();
          if (checkDoc.exists) {
            print('Đã xác nhận thông báo được lưu thành công');
          } else {
            print('Thông báo chưa được lưu thành công, thử lại...');
            // Thử lại một lần nữa với ID khác
            notificationId = 'task_notification_retry_${DateTime.now().millisecondsSinceEpoch}_${normalizedEmail.hashCode}';
            await Database.firestore.collection('Notifications').doc(notificationId).set({
              'title': title,
              'body': body,
              'receiveDate': currentDate,
              'receiveTo': normalizedEmail,
              'isRead': false,
              'timestamp': FieldValue.serverTimestamp(),
              'taskName': taskName,
              'projectName': projectName,
              'deadline': deadline,
              'assignedBy': currentUserName,
              'assignedByEmail': currentUserEmail,
            });
          }
        } catch (e) {
          print('Lỗi khi tạo thông báo cho $normalizedEmail: $e');
        }
      }
      
      // Hiển thị thông báo cục bộ cho người dùng hiện tại nếu họ là một trong những người được giao việc
      if (currentUserEmail != null && members.any((m) => m.trim().toLowerCase() == currentUserEmail.trim().toLowerCase())) {
        print('Hiển thị thông báo cục bộ cho người dùng hiện tại: $currentUserEmail');
        await showLocalNotification(
          title: title,
          body: body,
        );
      }
      
      // Hiển thị thông báo cục bộ bổ sung để đảm bảo người dùng nhận được thông báo
      await showLocalNotification(
        title: 'Đã giao công việc mới',
        body: 'Bạn đã giao công việc "$taskName" cho ${members.length} thành viên trong dự án "$projectName"',
      );
      
      // Gửi thông báo FCM đến tất cả người dùng
      if (normalizedEmails.isNotEmpty) {
        print('Gửi thông báo FCM đến tất cả thành viên...');
        await sendPushNotificationToUsers(
          title: title,
          body: body,
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
      
      // Lưu thông báo vào Firestore trước
      final currentUserEmail = Auth.auth.currentUser?.email;
      if (currentUserEmail != null) {
        String notificationId = 'local_notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
        DateTime today = DateTime.now();
        
        // Tạo dữ liệu thông báo
        Map<String, dynamic> notificationData = {
          'title': title,
          'body': body,
          'receiveDate': "${today.day}/${today.month}/${today.year}",
          'receiveTo': currentUserEmail, 
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        };
        
        // Lưu vào Firestore
        await Database.firestore.collection('Notifications').doc(notificationId).set(notificationData);
        print('Đã lưu thông báo vào Firestore với ID: $notificationId');
      } else {
        print('Không thể lưu thông báo vào Firestore: Người dùng chưa đăng nhập');
      }
      
      // Tạo chi tiết thông báo Android với độ ưu tiên cao nhất
      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
        // Thêm các tùy chọn để đảm bảo thông báo hiển thị dạng heads-up
        playSound: true,
        enableVibration: true,
        enableLights: true,
        autoCancel: true,
        fullScreenIntent: true, // Hiển thị ngay cả khi màn hình đang khóa
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        channelShowBadge: true,
      );
      
      // Chi tiết thông báo iOS với độ ưu tiên cao nhất
      const DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
              presentAlert: true, 
              presentBadge: true, 
              presentSound: true,
              interruptionLevel: InterruptionLevel.critical); // Mức độ ưu tiên cao nhất
      
      // Kết hợp cả hai nền tảng
      NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails, iOS: darwinNotificationDetails);
      
      // Hiển thị thông báo với ID ngẫu nhiên
      int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      // Đảm bảo thông báo được hiển thị
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: json.encode({
          'title': title, 
          'body': body,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      print('Đã hiển thị thông báo cục bộ với ID: $notificationId');
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

  // Phương thức kiểm tra thông báo
  Future<void> testNotification() async {
    try {
      print('Đang kiểm tra hệ thống thông báo...');
      
      final currentUserEmail = Auth.auth.currentUser?.email;
      final currentUserName = Auth.auth.currentUser?.displayName ?? 'Người dùng';
      
      if (currentUserEmail == null) {
        print('Không thể tạo thông báo test: Người dùng chưa đăng nhập');
        return;
      }
      
      print('Email người dùng hiện tại: $currentUserEmail');
      
      // Thêm thông báo vào danh sách thông báo
      DateTime now = DateTime.now();
      String currentDate = "${now.day}/${now.month}/${now.year}";
      
      // Tạo thông báo test đơn giản
      String notificationId = 'notification_${now.millisecondsSinceEpoch}';
      
      print('Đang tạo thông báo test với ID: $notificationId');
      
      Map<String, dynamic> notificationData = {
        'title': 'Thông báo kiểm tra',
        'body': 'Đây là thông báo kiểm tra hệ thống. Nếu bạn nhìn thấy nó, hệ thống thông báo đang hoạt động.',
        'receiveDate': currentDate,
        'receiveTo': currentUserEmail, 
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      try {
        await FirebaseFirestore.instance.collection('Notifications').doc(notificationId).set(notificationData);
        print('Đã tạo thông báo test thành công');
      } catch (e) {
        print('Lỗi khi tạo thông báo test: $e');
      }
      
      // Kiểm tra xem thông báo đã được tạo thành công chưa
      try {
        DocumentSnapshot checkDoc = await FirebaseFirestore.instance.collection('Notifications').doc(notificationId).get();
        print('Thông báo tồn tại: ${checkDoc.exists}');
      } catch (e) {
        print('Lỗi khi kiểm tra thông báo: $e');
      }
      
      // Hiển thị thông báo cục bộ
      await showLocalNotification(
        title: 'Thông báo kiểm tra',
        body: 'Đã tạo thông báo kiểm tra. Vui lòng kiểm tra danh sách thông báo.',
      );
      
      print('Đã tạo thông báo test trong Firestore thành công với ID: $notificationId');
    } catch (e) {
      print('Lỗi khi kiểm tra thông báo: $e');
    }
  }
  
  // Tạo thông báo test trong Firestore để kiểm tra hiển thị danh sách
  Future<void> createTestNotificationsInFirestore() async {
    try {
      final currentUserEmail = Auth.auth.currentUser?.email;
      if (currentUserEmail == null) {
        print('Không thể tạo thông báo test: Người dùng chưa đăng nhập');
        return;
      }
      
      print('Đang tạo thông báo test trong Firestore...');
      
      DateTime now = DateTime.now();
      String currentDate = "${now.day}/${now.month}/${now.year}";
      
      // Tạo thông báo test 1
      String notificationId1 = 'test_notification_${now.millisecondsSinceEpoch}_1';
      await Database.firestore.collection('Notifications').doc(notificationId1).set({
        'title': 'Thông báo kiểm tra 1',
        'body': 'Đây là thông báo kiểm tra trong danh sách. Vui lòng kiểm tra xem nó có hiển thị trong tab thông báo không.',
        'receiveDate': currentDate,
        'receiveTo': currentUserEmail, 
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Tạo thông báo test 2 (1 giây sau)
      await Future.delayed(Duration(seconds: 1));
      String notificationId2 = 'test_notification_${now.millisecondsSinceEpoch}_2';
      await Database.firestore.collection('Notifications').doc(notificationId2).set({
        'title': 'Thông báo kiểm tra 2',
        'body': 'Đây là thông báo kiểm tra thứ hai. Nó sẽ hiển thị trước thông báo đầu tiên nếu sắp xếp theo thời gian.',
        'receiveDate': currentDate,
        'receiveTo': currentUserEmail,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('Đã tạo thông báo test trong Firestore thành công với ID: $notificationId1 và $notificationId2');
    } catch (e) {
      print('Lỗi khi tạo thông báo test: $e');
    }
  }

  // Kiểm tra kết nối FCM
  Future<bool> checkFCMConnection() async {
    try {
      print('Kiểm tra kết nối FCM...');
      
      // Kiểm tra token FCM
      final token = await getDeviceToken();
      if (token.isEmpty) {
        print('Không thể lấy token FCM');
        return false;
      }
      print('Đã lấy token FCM thành công: ${token.substring(0, 10)}...');
      
      // Kiểm tra quyền thông báo
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('Chưa được cấp quyền thông báo: ${settings.authorizationStatus}');
        return false;
      }
      print('Đã được cấp quyền thông báo: ${settings.authorizationStatus}');
      
      // Kiểm tra đăng ký chủ đề
      final currentUserEmail = Auth.auth.currentUser?.email;
      if (currentUserEmail != null) {
        String sanitizedEmail = currentUserEmail.replaceAll(RegExp(r'[@.]'), '_');
        print('Đã đăng ký nhận thông báo cho chủ đề: $sanitizedEmail');
      }
      
      // Gửi thông báo kiểm tra
      await testNotification();
      
      return true;
    } catch (e) {
      print('Lỗi khi kiểm tra kết nối FCM: $e');
      return false;
    }
  }
}
