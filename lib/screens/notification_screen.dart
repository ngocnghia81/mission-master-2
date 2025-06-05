import 'package:flutter/material.dart';
import 'package:mission_master/routes/routes.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Chuyển hướng đến trang Notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, AppRoutes.notification);
    });
    
    // Widget tạm thời hiển thị trong khi chuyển hướng
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 