import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/userBloc/bloc.dart';
import 'package:mission_master/bloc/userBloc/events.dart';
import 'package:mission_master/bloc/userBloc/states.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/icons.dart';
import 'package:mission_master/constants/image.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/utils/utils.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryColor,
              AppColors.accentColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo hoặc hình ảnh ứng dụng
                  Image.asset(
                    AppImages.user,
                    width: size.width * 0.6,
                  ),
                  SizedBox(height: size.height * 0.04),
                  
                  // Tiêu đề ứng dụng
                  Text(
                    'Mission Master',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: size.height * 0.01),
                  
                  // Mô tả ngắn
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Giải pháp quản lý công việc toàn diện',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.08),
                  
                  // Nút đăng nhập với Google
                  BlocConsumer<LoginSignUpBloc, UserStates>(
                    listener: (context, state) {
                      if (state is Userloading && state.loading == true) {
                        Utils.showtoast('Đang đăng nhập...');
                      } else if (state is Userloading && state.loading == false) {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.main);
                      }
                    },
                    builder: (context, state) {
                      if (state is Userloading && state.loading == true) {
                        return CircularProgressIndicator(color: Colors.white);
                      }
                      
                      return Container(
                        width: size.width * 0.7,
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () {
                            BlocProvider.of<LoginSignUpBloc>(context)
                                .add(GoogleSigning(true));
                          },
                          icon: Image.asset(
                            AppIcons.googleLogo,
                            height: 24,
                          ),
                          label: Text(
                            'Đăng nhập với Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: size.height * 0.06),
                  
                  // Footer
                  Text(
                    'Phiên bản 1.0.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 