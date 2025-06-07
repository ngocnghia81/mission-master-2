import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:mission_master/bloc/addMemberToProject/addMemberstates.dart';
import 'package:mission_master/bloc/addMemberToProject/addmemberevents.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/email/email_sending.dart';
import 'package:mission_master/data/services/user_validation_service.dart';
import 'package:mission_master/injection/database.dart';

class AddMemberToProjectBloc
    extends Bloc<AddMemberToProjectEvents, AddMemberToProjectStates> {
  var project = locator<Database>;
  final projetController = Get.put(ProjectController());
  AddMemberToProjectBloc() : super(InitialState()) {
    on<AddMemberToProject>((event, emit) async {
      try {
        if (event.memberEmail.isEmpty) {
          emit(AddErrorState(message: 'Vui lòng nhập email thành viên'));
          return;
        }
        
        // Kiểm tra email có hợp lệ không
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(event.memberEmail)) {
          emit(AddErrorState(message: 'Email không hợp lệ'));
          return;
        }
        
        // Kiểm tra email có trong hệ thống hay không
        final bool isEmailRegistered = await UserValidationService.isEmailRegistered(event.memberEmail);
        if (!isEmailRegistered) {
          emit(AddErrorState(message: 'Email "${event.memberEmail}" chưa đăng ký trong hệ thống.\nChỉ có thể thêm những email đã có tài khoản.'));
          return;
        }
        
        // Kiểm tra email đã có trong dự án chưa
        final String projectId = projetController.projectId.string;
        final bool isAlreadyMember = await UserValidationService.isUserInProject(event.memberEmail, projectId);
        if (isAlreadyMember) {
          emit(AddErrorState(message: 'Thành viên này đã có trong dự án'));
          return;
        }
        
        // Kiểm tra quyền thêm thành viên
        final bool hasPermission = await UserValidationService.hasPermission(
          'ADD_MEMBER',
          projectId: projectId,
        );
        if (!hasPermission) {
          emit(AddErrorState(message: 'Bạn không có quyền thêm thành viên vào dự án này'));
          return;
        }
        
        // Thêm thành viên vào dự án
        await project().addMemberToProject(email: event.memberEmail);
        
        // Gửi email thông báo
        SendEmail.sendEmail(
          email: [event.memberEmail],
          projectName: projetController.projectName.value,
          subject: projetController.projectName.value,
        );

        emit(MemberAddedToProjectState(message: 'Đã thêm thành viên thành công'));
      } catch (e) {
        print('Lỗi khi thêm thành viên: $e');
        emit(AddErrorState(message: 'Có lỗi xảy ra: ${e.toString()}'));
      }
    });
  }
}
