import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/userBloc/bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/tasks/tasks_bloc.dart';
import 'package:mission_master/bloc/memberBloc/member_bloc.dart';
import 'package:mission_master/bloc/addprojectBloc/project_bloc.dart';
import 'package:mission_master/bloc/TaskBloc/task_bloc.dart';
import 'package:mission_master/bloc/addMemberToProject/addMemberBloc.dart';
import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_bloc.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/theme.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/models/theme_preference.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:mission_master/firebase_options.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/notification/notification_services.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/routes/routes_generator.dart';
import 'package:mission_master/screens/login_screen.dart';
import 'package:mission_master/screens/main_screen.dart';
import 'package:mission_master/screens/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mission_master/providers/statistics_provider.dart';

// Khởi tạo Firebase là Future
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  // Đảm bảo binding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tắt chế độ sửa lỗi Skia để tránh lỗi OpenGL
  debugPaintSizeEnabled = false;
  
  // Khởi tạo Firebase trước tiên
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Cấu hình thông báo Firebase
  await _configureFirebaseMessaging();
  
  // Đăng ký callback xử lý thông báo nền
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
  
  // Khởi tạo SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Kiểm tra xem người dùng đã xem onboarding chưa
  final hasSeenOnboarding = sharedPreferences.getBool('has_seen_onboarding') ?? false;
  
  // Thiết lập các phụ thuộc sau khi Firebase đã được khởi tạo
  setup();

  
  // Chạy ứng dụng
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => ThemePreference()),
      ],
      child: MyApp(
        sharedPreferences: sharedPreferences,
        hasSeenOnboarding: hasSeenOnboarding,
      ),
    ),
  );
}

// Cấu hình Firebase Messaging
Future<void> _configureFirebaseMessaging() async {
  // Yêu cầu quyền thông báo
  final messaging = FirebaseMessaging.instance;
  
  // Yêu cầu quyền thông báo trên iOS
  await messaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: true,
    criticalAlert: true,
    provisional: false,
    sound: true,
  );
  
  // Cấu hình nhận thông báo khi ứng dụng đang chạy
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, // Hiển thị cảnh báo
    badge: true, // Hiển thị badge
    sound: true, // Phát âm thanh
  );
  
  // Đăng ký lắng nghe thông báo khi ứng dụng đang chạy
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Nhận thông báo khi ứng dụng đang chạy: ${message.notification?.title}');
    
    // Hiển thị thông báo ngay cả khi ứng dụng đang chạy
    if (message.notification != null) {
      // Lấy dịch vụ thông báo từ locator
      final notificationService = locator<NotificationServices>();
      
      // Hiển thị thông báo
      notificationService.showNotifications(message);
    }
  });
  
  // Lấy token thiết bị và in ra console để debug
  final token = await messaging.getToken();
  print('FCM Token: $token');
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  // Khởi tạo Firebase khi nhận tin nhắn nền
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );
  
  // Ghi log thông báo nhận được
  print('Đã nhận thông báo nền: ${message.notification?.title}');
  print('Nội dung: ${message.notification?.body}');
  print('Data: ${message.data}');
  
  // Lưu thông báo vào cơ sở dữ liệu nếu cần
  if (message.notification != null) {
    try {
      setup(); // Khởi tạo dependency injection
      final Database db = locator<Database>();
      await db.saveNotifications(
        title: message.notification!.title ?? 'Thông báo mới',
        body: message.notification!.body ?? 'Bạn có một thông báo mới',
      );
    } catch (e) {
      print('Lỗi khi lưu thông báo nền: $e');
    }
  }
}

class MyApp extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  final bool hasSeenOnboarding;
  
  const MyApp({
    super.key, 
    required this.sharedPreferences,
    required this.hasSeenOnboarding,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Đặt orientation chỉ cho phép portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Cấu hình status bar trong suốt
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    // Chuyển đổi thông báo cũ sang định dạng mới nếu người dùng đã đăng nhập
    _migrateNotificationsIfNeeded();
    
    // Khởi tạo hệ thống thông báo sau khi ứng dụng đã tải
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }
  
  // Khởi tạo hệ thống thông báo
  Future<void> _initializeNotifications() async {
    try {
      if (Auth.auth.currentUser != null) {
        print('Đang khởi tạo hệ thống thông báo...');
        final notificationService = locator<NotificationServices>();
        await notificationService.initializeNotifications(context);

        print('Đã khởi tạo hệ thống thông báo thành công');
      } else {
        print('Chưa đăng nhập, bỏ qua khởi tạo thông báo');
      }
    } catch (e) {
      print('Lỗi khi khởi tạo hệ thống thông báo: $e');
    }
  }
  
  // Chuyển đổi thông báo cũ sang định dạng mới
  Future<void> _migrateNotificationsIfNeeded() async {
    if (Auth.auth.currentUser != null) {
      var database = locator<Database>();
      await database.migrateNotifications();
    }
  }
  
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemePreference>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      title: 'Mission Master',
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.lightTheme,
      initialRoute: widget.hasSeenOnboarding ? 
          (Auth.auth.currentUser == null ? AppRoutes.login : AppRoutes.main) : 
          AppRoutes.onboarding,
      onGenerateRoute: RouteGenerator.generateRoute,
      home: _buildHomeScreen(),
    );
  }
  
  Widget _buildHomeScreen() {
    // Nếu chưa xem onboarding, hiển thị onboarding screen
    if (!widget.hasSeenOnboarding) {
      return const OnboardingScreen();
    }
    
    // Nếu chưa đăng nhập, hiển thị màn hình đăng nhập
    if (Auth.auth.currentUser == null) {
      return BlocProvider(
        create: (context) => LoginSignUpBloc(),
        child: const LoginScreen(),
      );
    }
    
    // Nếu đã đăng nhập, hiển thị màn hình chính
    return MultiBlocProvider(
      providers: [
        BlocProvider<NavBarBloc>(
          create: (context) => NavBarBloc(),
        ),
        BlocProvider<TasksBloc>(
          create: (context) => TasksBloc(
            TaskRepository(
              taskDataProvider: TaskDataProvider(widget.sharedPreferences),
            ),
          ),
        ),
        BlocProvider<MemberBloc>(
          create: (context) => MemberBloc(),
        ),
        BlocProvider<ProjectBloc>(
          create: (context) => ProjectBloc(),
        ),
      ],
      child: const MainScreen(),
    );
  }
}
