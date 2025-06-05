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
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/routes/routes_generator.dart';
import 'package:mission_master/screens/login_screen.dart';
import 'package:mission_master/screens/main_screen.dart';
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
  
  // Đăng ký callback xử lý thông báo nền
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
  
  // Khởi tạo SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Thiết lập các phụ thuộc sau khi Firebase đã được khởi tạo
  setup();
  
  // Chạy ứng dụng
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => ThemePreference()),
      ],
      child: MyApp(sharedPreferences: sharedPreferences),
    ),
  );
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
  
  const MyApp({super.key, required this.sharedPreferences});

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
    
    // Tạo TaskRepository để sử dụng chung
    final taskRepository = TaskRepository(
      taskDataProvider: TaskDataProvider(widget.sharedPreferences)
    );
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      title: 'Mission Master',
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.login,
      onGenerateRoute: RouteGenerator.generateRoute,
      home: Auth.auth.currentUser == null 
          ? BlocProvider(
              create: (context) => LoginSignUpBloc(),
              child: const LoginScreen(),
            ) 
          : MultiBlocProvider(
              providers: [
                BlocProvider<NavBarBloc>(
                  create: (context) => NavBarBloc(),
                ),
                BlocProvider<TasksBloc>(
                  create: (context) => TasksBloc(taskRepository),
                ),
                BlocProvider<MemberBloc>(
                  create: (context) => MemberBloc(),
                ),
                BlocProvider<ProjectBloc>(
                  create: (context) => ProjectBloc(),
                ),
              ],
              child: const MainScreen(),
            ),
      // Thêm BlocProvider cho toàn bộ ứng dụng để đảm bảo TasksBloc có sẵn ở mọi nơi
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider<TasksBloc>(
              create: (context) => TasksBloc(taskRepository),
            ),
          ],
          child: child!,
        );
      },
    );
  }
}
