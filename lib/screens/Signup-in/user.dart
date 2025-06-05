import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/Utils/utils.dart';
import 'package:mission_master/bloc/userBloc/bloc.dart';
import 'package:mission_master/bloc/userBloc/events.dart';
import 'package:mission_master/bloc/userBloc/states.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/tasks/tasks_bloc.dart';
import 'package:mission_master/bloc/memberBloc/member_bloc.dart';
import 'package:mission_master/bloc/addprojectBloc/project_bloc.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/icons.dart';
import 'package:mission_master/constants/image.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/screens/main_screen.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User extends StatelessWidget {
  const User({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.workspaceGradientColor1[1],
              AppColors.workspaceGradientColor2[1],
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(AppImages.user),
            RichText(
              text: TextSpan(
                text: 'Chào mừng đến với ',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: AppFonts.normal,
                  fontSize: size.width * 0.06,
                ),
                children: [
                  const TextSpan(
                      text: 'Mission Master',
                      style: TextStyle(
                        fontWeight: AppFonts.bold,
                      )),
                ],
              ),
            ),
            text(
              title: "Giải pháp quản lý công việc toàn diện!",
              fontSize: size.width * 0.05,
              fontWeight: AppFonts.normal,
              color: AppColors.white,
              align: TextAlign.center,
            ),
            SizedBox(
              height: size.height * 0.02,
            ),
            BlocConsumer<LoginSignUpBloc, UserStates>(
              listener: (context, state) async {
                if (state is Userloading && state.loading == false) {
                  // Get SharedPreferences instance
                  final sharedPreferences = await SharedPreferences.getInstance();
                  
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => MultiBlocProvider(
                        providers: [
                          BlocProvider<NavBarBloc>(
                            create: (context) => NavBarBloc(),
                          ),
                          BlocProvider<TasksBloc>(
                            create: (context) => TasksBloc(
                              TaskRepository(
                                taskDataProvider: TaskDataProvider(sharedPreferences),
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
                      ),
                    ),
                  );
                } else if (state is Userloading && state.loading == true) {
                  Utils.showtoast('Đang đăng nhập');
                }
              },
              builder: (context, state) {
                if (state is EnableGoogleSignin) {
                  return SizedBox(
                    width: size.width * 0.8,
                    height: size.height * 0.07,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        shape: const BeveledRectangleBorder(),
                        textStyle: const TextStyle(
                          color: AppColors.black,
                        ),
                      ),
                      onPressed: () {
                        BlocProvider.of<LoginSignUpBloc>(context)
                            .add(GoogleSigning(true));
                      },
                      icon: Image.asset(
                        AppIcons.googleLogo,
                        height: size.height * 0.04,
                      ),
                      label: text(
                        title: 'Google',
                        fontSize: size.width * 0.05,
                        fontWeight: AppFonts.normal,
                        color: AppColors.black,
                        align: TextAlign.center,
                      ),
                    ),
                  );
                } else if (state is Userloading && state.loading == true) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      2,
                      (index) => Container(
                        width: size.width * 0.8,
                        height: size.height * 0.07,
                        margin: EdgeInsets.only(
                          bottom: size.height * 0.02,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors
                                .workspaceGradientColor1[1]
                                .withOpacity(0.7),
                            shape: const BeveledRectangleBorder(),
                          ),
                          onPressed: () {
                            BlocProvider.of<LoginSignUpBloc>(context)
                                .add(LoginSignupEvent());
                          },
                          child: text(
                              title: ["Đăng nhập", "Đăng ký"][index],
                              fontSize: size.width * 0.04,
                              fontWeight: AppFonts.semiBold,
                              color: AppColors.white,
                              align: TextAlign.start),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
