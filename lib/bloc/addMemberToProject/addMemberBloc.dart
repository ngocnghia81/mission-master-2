import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:mission_master/bloc/addMemberToProject/addMemberstates.dart';
import 'package:mission_master/bloc/addMemberToProject/addmemberevents.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/email/email_sending.dart';
import 'package:mission_master/injection/database.dart';

class AddMemberToProjectBloc
    extends Bloc<AddMemberToProjectEvents, AddMemberToProjectStates> {
  var project = locator<Database>;
  final projetController = Get.put(ProjectController());
  AddMemberToProjectBloc() : super(InitialState()) {
    on<AddMemberToProject>((event, emit) async {
      try {
        if (event.memberEmail.isNotEmpty) {
          SendEmail.sendEmail(
            email: [event.memberEmail],
            projectName: projetController.projectName.value,
            subject: projetController.projectName.value,
          );
          await project().addMemberToProject(email: event.memberEmail);

          emit(MemberAddedToProjectState(message: 'Đã thêm thành viên thành công'));
        } else {
          emit(AddErrorState(message: 'Không thể thêm thành viên'));
        }
      } catch (e) {
        emit(AddErrorState(message: e.toString()));
      }
    });
  }
}
