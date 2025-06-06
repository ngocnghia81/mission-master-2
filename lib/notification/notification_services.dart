import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';

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
        // Chuyển đến màn hình thông báo
        Navigator.of(context).pushNamed(AppRoutes.notification);
        
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
      // Chuyển đến màn hình thông báo
      Navigator.of(context).pushNamed(AppRoutes.notification);
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
    // Lưu thông báo vào Firestore cho mỗi thành viên
    DateTime today = DateTime.now();
    String currentDate = "${today.day}/${today.month}/${today.year}";
    
    for (String member in members) {
      // Lưu thông báo vào Firestore
      await Database.firestore.collection('Notifications').doc().set({
        'title': 'Công việc mới trong $projectName',
        'body': 'Bạn đã được giao công việc: $taskName. Hạn chót: $deadline',
        'receiveDate': currentDate,
        'receiveTo': member,
      });
      
      // Hiển thị thông báo cục bộ nếu người dùng là người giao việc
      if (Auth.auth.currentUser?.email == member) {
        await showLocalNotification(
          title: 'Công việc mới trong $projectName',
          body: 'Bạn đã được giao công việc: $taskName. Hạn chót: $deadline',
        );
      }
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
    
    // Lưu thông báo vào Firestore
    await project().saveNotifications(title: title, body: body);
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


}
