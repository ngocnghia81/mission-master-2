import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/memberBloc/member_bloc.dart';
import 'package:mission_master/bloc/TaskBloc/task_bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/addprojectBloc/project_bloc.dart';
import 'package:mission_master/bloc/addMemberToProject/addMemberBloc.dart';
import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_bloc.dart';
import 'package:mission_master/bloc/tasks/tasks_bloc.dart' as tasks_bloc;
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/screens/workspace/add_member_screen.dart';
import 'package:mission_master/screens/workspace/add_task.dart';
import 'package:mission_master/screens/workspace/all_workspace.dart';
import 'package:mission_master/screens/home_screen.dart';
import 'package:mission_master/screens/login_screen.dart';
import 'package:mission_master/screens/main_screen.dart';
import 'package:mission_master/screens/notification_screen.dart';
import 'package:mission_master/screens/statistics/project_statistics_screen.dart';
import 'package:mission_master/screens/task/task_detail_screen.dart';
import 'package:mission_master/screens/workspace/workspace_board_screen.dart';
import 'package:mission_master/screens/workspace/workspace_chat_screen.dart';
import 'package:mission_master/screens/workspace_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case AppRoutes.main:
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider<NavBarBloc>(
                create: (context) => NavBarBloc(),
              ),
              BlocProvider<MemberBloc>(
                create: (context) => MemberBloc(),
              ),
              BlocProvider<ProjectBloc>(
                create: (context) => ProjectBloc(),
              ),
            ],
            child: MainScreen(),
          ),
        );
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
      case AppRoutes.addMember:
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider<AddMemberToProjectBloc>(
                create: (context) => AddMemberToProjectBloc(),
              ),
              BlocProvider<RemoveMemberFromProjectBloc>(
                create: (context) => RemoveMemberFromProjectBloc(),
              ),
            ],
            child: AddMemberScreen(),
          ),
        );
      case AppRoutes.addTask:
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => MemberBloc()),
              BlocProvider(create: (context) => TaskBloc()),
            ],
            child: AddTask(),
          ),
        );
      case AppRoutes.workSpaceDetail:
        return MaterialPageRoute(builder: (_) => WorkspaceDetail());
      case AppRoutes.notification:
        return MaterialPageRoute(builder: (_) => NotificationScreen());
      case AppRoutes.allWorkspace:
        return MaterialPageRoute(builder: (_) => AllWorkspace());
      case AppRoutes.taskDetail:
        if (args is Task) {
          return MaterialPageRoute(
            builder: (_) => TaskDetailScreen(task: args),
          );
        }
        return _errorRoute();
      case AppRoutes.projectStatistics:
        if (args is Map<String, String>) {
          return MaterialPageRoute(
            builder: (_) => ProjectStatisticsScreen(
              projectId: args['projectId']!,
              projectName: args['projectName']!,
            ),
          );
        }
        return _errorRoute();
      case AppRoutes.workspaceChat:
        if (args is Map<String, String>) {
          return MaterialPageRoute(
            builder: (_) => WorkspaceChatScreen(
              projectId: args['projectId']!,
              projectName: args['projectName']!,
            ),
          );
        }
        return _errorRoute();
      case AppRoutes.workspaceBoard:
        if (args is Map<String, String>) {
          return MaterialPageRoute(
            builder: (_) => WorkspaceBoardScreen(
              projectId: args['projectId']!,
              projectName: args['projectName']!,
            ),
          );
        }
        return _errorRoute();
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Lỗi'),
        ),
        body: Center(
          child: Text('Không tìm thấy trang'),
        ),
      );
    });
  }
} 