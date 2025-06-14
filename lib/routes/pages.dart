import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:mission_master/bloc/HomePageTaskTabsBloc/bloc.dart';
import 'package:mission_master/bloc/TaskBloc/task_bloc.dart';
import 'package:mission_master/bloc/addMemberToProject/addMemberBloc.dart';
import 'package:mission_master/bloc/addprojectBloc/project_bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/memberBloc/member_bloc.dart';
import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_bloc.dart';
import 'package:mission_master/bloc/userBloc/bloc.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/screens/Signup-in/user.dart';
import 'package:mission_master/screens/addWorkspace/add_workspace.dart';
import 'package:mission_master/screens/comments/comments_screen.dart';
import 'package:mission_master/screens/home_screen.dart';
import 'package:mission_master/screens/main_screen.dart';
import 'package:mission_master/screens/notification/notification.dart';
import 'package:mission_master/screens/workspace/add_member_screen.dart';
import 'package:mission_master/screens/workspace/add_task.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart'
    as GetTrasition;
import 'package:mission_master/screens/workspace/all_workspace.dart';
import 'package:mission_master/screens/workspace_detail_screen.dart';


class Pages {
  static List<GetPage<dynamic>> pages = [
    GetPage(
      name: AppRoutes.main,
      page: () => MultiBlocProvider(
        providers: [
          BlocProvider<NavBarBloc>(
            create: (context) => NavBarBloc(),
          ),
          BlocProvider<homePageTabBarBloc>(
            create: (context) => homePageTabBarBloc(),
          ),
          BlocProvider<LoginSignUpBloc>(
            create: (context) => LoginSignUpBloc(),
          ),
          BlocProvider<ProjectBloc>(
            create: (context) => ProjectBloc(),
          ),
          BlocProvider<MemberBloc>(
            create: (context) => MemberBloc(),
          ),
        ],
        child: MainScreen(),
      ),
      transition: GetTrasition.Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.user,
      page: () => BlocProvider(
        create: (context) => LoginSignUpBloc(),
        child: User(),
      ),
      transition: GetTrasition.Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => HomeScreen(),
      transition: GetTrasition.Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.addMember,
      page: () => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AddMemberToProjectBloc(),
          ),
          BlocProvider(
            create: (context) => RemoveMemberFromProjectBloc(),
          ),
        ],
        child: AddMemberScreen(),
      ),
      transition: GetTrasition.Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.addTask,
      page: () => MultiBlocProvider(
        providers: [
          BlocProvider<MemberBloc>(
            create: (context) => MemberBloc(),
          ),
          BlocProvider<TaskBloc>(
            create: (context) => TaskBloc(),
          ),
        ],
        child: AddTask(),
      ),
      transition: GetTrasition.Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.addWorkspce,
      page: () => AddWorkspace(),
      transition: GetTrasition.Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.notification,
      page: () => Notifications(),
      transition: GetTrasition.Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.workSpaceDetail,
      page: () => WorkspaceDetail(),
      transition: GetTrasition.Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.allWorkspace,
      page: () => AllWorkspace(),
      transition: GetTrasition.Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 500),
    ),
    GetPage(
      name: AppRoutes.comment,
      page: () => Comments(),
      transition: GetTrasition.Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 500),
    ),
  ];
}