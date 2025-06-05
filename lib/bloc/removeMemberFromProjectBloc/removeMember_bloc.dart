import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_events.dart';
import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_states.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';

class RemoveMemberFromProjectBloc
    extends Bloc<RemoveMemberFromProjectEvents, RemoveMemberFromProjectStates> {
  var project = locator<Database>;
  RemoveMemberFromProjectBloc() : super(InitialState()) {
    on<RemoveMemberFromProject>((event, emit) async {
      try {
        if (event.memberEmail.isNotEmpty) {
          await project().removeMemberToProject(email: event.memberEmail);
          emit(MemberRemovedFromProjectState(
              message: 'Đã xóa thành viên thành công'));
        } else {
          emit(ErrorState(message: 'Không thể xóa thành viên'));
        }
      } catch (e) {
        emit(ErrorState(message: e.toString()));
      }
    });
  }
}
