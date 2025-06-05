import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/TaskBloc/task_events.dart';
import 'package:mission_master/bloc/TaskBloc/task_states.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';

class TaskBloc extends Bloc<TaskEvents, TaskStates> {
  var project = locator<Database>;
  TaskBloc() : super(InitialState()) {
    on<AddTasks>((event, emit) async {
      if (event.taskName.isNotEmpty &&
          event.taskDescription.isNotEmpty &&
          event.deadlineDate.isNotEmpty &&
          event.deadlineTime.isNotEmpty) {
        print(event.member);
        bool added = await project().addTaskToProject(
            task: event.taskName,
            description: event.taskDescription,
            date: event.deadlineDate,
            time: event.deadlineTime,
            members: event.member,
            priority: event.priority,
            isRecurring: event.isRecurring,
            recurringInterval: event.recurringInterval);

        if (added) {
          emit(TaskAdded(message: 'Công việc đã được thêm vào dự án'));
        } else {
          emit(ErrorState('Không thể thêm công việc: Vui lòng thử lại'));
        }
      } else {
        emit(ErrorState(
            'Vui lòng điền đầy đủ thông tin công việc'));
      }
    });
  }
}
