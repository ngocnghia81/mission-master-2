import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/events.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/states.dart';
import 'package:mission_master/bloc/tasks/tasks_bloc.dart';
import 'package:mission_master/bloc/userBloc/bloc.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/icons.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/models/theme_preference.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/notification/notification_services.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/screens/addWorkspace/add_workspace.dart';
import 'package:mission_master/screens/home_screen.dart';
import 'package:mission_master/screens/notification/notification.dart';
import 'package:mission_master/screens/Signup-in/user.dart';
import 'package:mission_master/screens/workspace/all_workspace.dart';
import 'package:mission_master/screens/ai_test_screen.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final project = locator<Database>();
  final NotificationServices _notificationServices = NotificationServices();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo dịch vụ thông báo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationServices.initializeNotifications(context);
    });
    
    // Chuyển đổi thông báo cũ sang định dạng mới
    project.migrateNotifications();
    
    // Kiểm tra và gửi thông báo về các công việc đến hạn
    project.sendDeadlineReminder();
  }
  
  // Lấy tiêu đề dựa vào index tab hiện tại
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Mission Master';
      case 1:
        return 'Tạo không gian làm việc';
      case 2:
        return 'Không gian làm việc';
      case 3:
        return 'Thông báo';
      default:
        return 'Mission Master';
    }
  }

  // Đánh dấu tất cả thông báo đã đọc
  Future<void> _markAllNotificationsAsRead() async {
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
    }
  }

  // Làm mới thông báo
  void _refreshNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã làm mới thông báo'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final themeProvider = Provider.of<ThemePreference>(context);
    
    List<Widget> bottomNavBarPages = [
      const HomeScreen(),
      const AddWorkspace(),
      const AllWorkspace(),
      const Notifications(),
    ];
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, themeProvider),
      appBar: AppBar(
        automaticallyImplyLeading: false, // Ẩn nút quay lại
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: BlocBuilder<NavBarBloc, NavBarStates>(
          builder: (context, state) {
            if (state is pageNavigate) {
              return Text(_getAppBarTitle(state.index));
            }
            return Text('Mission Master');
          }
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        actions: [
          // Thêm nút kiểm tra thông báo
          IconButton(
            icon: Icon(Icons.bug_report),
            tooltip: 'Kiểm tra thông báo',
            onPressed: () async {
              try {
                await _notificationServices.testNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã gửi thông báo kiểm tra'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi khi gửi thông báo kiểm tra: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          BlocBuilder<NavBarBloc, NavBarStates>(
            builder: (context, state) {
              // Hiển thị actions khác nhau tùy vào tab hiện tại
              if (state is pageNavigate && state.index == 3) {
                // Tab thông báo - hiển thị actions đặc biệt
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.done_all),
                      tooltip: 'Đánh dấu tất cả đã đọc',
                      onPressed: () => _markAllNotificationsAsRead(),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      tooltip: 'Làm mới',
                      onPressed: () => _refreshNotifications(),
                    ),
                  ],
                );
              } else {
                // Các tab khác - hiển thị icon thông báo
                return IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () {
                    BlocProvider.of<NavBarBloc>(context).add(currentPage(index: 3));
                  },
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              width: 1,
              color: Colors.grey,
            ),
          ),
        ),
        child: BottomAppBar(
          elevation: 0.0,
          color: AppColors.white,
          height: size.height * 0.06,
          padding: EdgeInsets.symmetric(
            vertical: size.height * 0.00,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (index) => IconButton(
                onPressed: () {
                  BlocProvider.of<NavBarBloc>(context)
                      .add(currentPage(index: index));
                },
                icon: BlocBuilder<NavBarBloc, NavBarStates>(
                  builder: (context, state) {
                    return Icon(
                      AppIcons.bottomNavBarIcon[index],
                      color: (state is pageNavigate && state.index == index)
                          ? AppColors.black
                          : AppColors.grey,
                      size: size.width * 0.085,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<NavBarBloc, NavBarStates>(
          bloc: BlocProvider.of<NavBarBloc>(context),
          builder: (context, states) {
            if (states is pageNavigate) {
              return AnimatedSwitcher(
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  duration: Duration(milliseconds: 250),
                  child: bottomNavBarPages[states.index]);
            } else {
              return SizedBox();
            }
          }),
    );
  }
  
  Widget _buildDrawer(BuildContext context, ThemePreference themeProvider) {
    final size = MediaQuery.of(context).size;
    final user = Auth.auth.currentUser;
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: user?.photoURL != null 
                      ? NetworkImage(user!.photoURL!) 
                      : null,
                  child: user?.photoURL == null 
                      ? Icon(Icons.person, size: 40, color: AppColors.primaryColor) 
                      : null,
                ),
                SizedBox(height: 10),
                text(
                  title: user?.displayName ?? "Người dùng",
                  fontSize: size.width * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  align: TextAlign.start,
                ),
                text(
                  title: user?.email ?? "",
                  fontSize: size.width * 0.035,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                  align: TextAlign.start,
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context,
            Icons.home,
            'Trang chủ',
            () {
              Navigator.pop(context);
              BlocProvider.of<NavBarBloc>(context).add(currentPage(index: 0));
            },
          ),
          _buildDrawerItem(
            context,
            Icons.add_box,
            'Tạo không gian làm việc',
            () {
              Navigator.pop(context);
              BlocProvider.of<NavBarBloc>(context).add(currentPage(index: 1));
            },
          ),
          _buildDrawerItem(
            context,
            Icons.work,
            'Không gian làm việc',
            () {
              Navigator.pop(context);
              BlocProvider.of<NavBarBloc>(context).add(currentPage(index: 2));
            },
          ),
          _buildDrawerItem(
            context,
            Icons.notifications,
            'Thông báo',
            () {
              Navigator.pop(context);
              BlocProvider.of<NavBarBloc>(context).add(currentPage(index: 3));
            },
          ),
          Divider(),
          Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              'Tính năng Doanh nghiệp',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            Icons.dashboard,
            'Enterprise Dashboard',
            () {
              Navigator.pop(context);
              // TODO: Select project from list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Vui lòng chọn dự án trước'))
              );
            },
          ),
          _buildDrawerItem(
            context,
            Icons.add_business,
            'Tạo dự án Enterprise',
            () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.enterpriseProject);
            },
          ),
          _buildDrawerItem(
            context,
            Icons.business,
            'Dự án Enterprise',
            () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.enterpriseProjectsList);
            },
          ),
          _buildDrawerItem(
            context,
            Icons.admin_panel_settings,
            'Quản lý vai trò & quyền',
            () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.roleManagement);
            },
          ),
          _buildDrawerItem(
            context,
            Icons.inventory,
            'Quản lý tài nguyên',
            () {
              Navigator.pop(context);
              // TODO: Select project from list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Vui lòng chọn dự án trước'))
              );
            },
          ),
          _buildDrawerItem(
            context,
            Icons.analytics,
            'Báo cáo & Phân tích',
            () {
              Navigator.pop(context);
              // TODO: Select project from list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Vui lòng chọn dự án trước'))
              );
            },
          ),
          Divider(),
          Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              '🤖 AI Features',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue[600],
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            Icons.psychology,
            '🧪 AI Sentiment Test',
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AITestScreen(),
                ),
              );
            },
            color: Colors.blue,
          ),
          Divider(),
          SwitchListTile(
            title: Text('Chế độ tối'),
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: isDarkMode,
            activeColor: AppColors.primaryColor,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),
          _buildDrawerItem(
            context,
            Icons.settings,
            'Cài đặt',
            () {
              Navigator.pop(context);
              // Thêm chức năng cài đặt sau này
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chức năng đang phát triển'))
              );
            },
          ),
          _buildDrawerItem(
            context,
            Icons.help,
            'Trợ giúp',
            () {
              Navigator.pop(context);
              // Thêm chức năng trợ giúp sau này
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chức năng đang phát triển'))
              );
            },
          ),
          _buildDrawerItem(
            context,
            Icons.logout,
            'Đăng xuất',
            () async {
              // Hiển thị dialog xác nhận
              bool confirm = await _showLogoutConfirmDialog(context);
              if (confirm) {
                try {
                  // Đăng xuất
                  await Auth.GoogleLogout();
                  
                  // Điều hướng về trang đăng nhập với pushNamedAndRemoveUntil
                  // để tránh xung đột Provider
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login,
                      (route) => false, // Xóa tất cả các route cũ
                    );
                  }
                } catch (e) {
                  // Xử lý lỗi nếu có
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi khi đăng xuất: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            color: Colors.red,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawerItem(
    BuildContext context, 
    IconData icon, 
    String title, 
    VoidCallback onTap, 
    {Color color = Colors.black}
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color),
      ),
      onTap: onTap,
    );
  }
  
  Future<bool> _showLogoutConfirmDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận'),
        content: Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Đăng xuất'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ) ?? false;
  }
}
