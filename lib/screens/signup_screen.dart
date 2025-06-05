import 'package:flutter/material.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/screens/Signup-in/user.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Chuyển hướng đến trang User
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, AppRoutes.user);
    });
    
    // Widget tạm thời hiển thị trong khi chuyển hướng
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 