import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/events.dart';
import 'package:mission_master/routes/routes.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Chuyển hướng đến MainScreen và tab thông báo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Chuyển về MainScreen
      Navigator.pushNamedAndRemoveUntil(
        context, 
        AppRoutes.main, 
        (route) => false
      );
      
      // Chuyển đến tab thông báo
      try {
        final navBarBloc = context.read<NavBarBloc>();
        navBarBloc.add(currentPage(index: 3));
      } catch (e) {
        print('Không thể chuyển tab thông báo: $e');
      }
    });
    
    // Widget tạm thời hiển thị trong khi chuyển hướng
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 