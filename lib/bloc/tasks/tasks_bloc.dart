import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object> get props => [];
}

class LoadTasks extends TasksEvent {}

class AddTask extends TasksEvent {
  final String title;
  final String description;
  final String deadlineDate;
  final String deadlineTime;
  final List<String> members;
  final String projectName;

  const AddTask({
    required this.title,
    required this.description,
    required this.deadlineDate,
    required this.deadlineTime,
    required this.members,
    required this.projectName,
  });

  @override
  List<Object> get props => [title, description, deadlineDate, deadlineTime, members, projectName];
}

class UpdateTaskStatus extends TasksEvent {
  final String taskId;
  final String status;

  const UpdateTaskStatus({required this.taskId, required this.status});

  @override
  List<Object> get props => [taskId, status];
}

class FilterByStatus extends TasksEvent {
  final String status;

  const FilterByStatus({required this.status});

  @override
  List<Object> get props => [status];
}

class FilterByProject extends TasksEvent {
  final String projectName;

  const FilterByProject({required this.projectName});

  @override
  List<Object> get props => [projectName];
}

class FilterByDate extends TasksEvent {
  final DateTime date;

  const FilterByDate({required this.date});

  @override
  List<Object> get props => [date];
}

class FilterByAssignedUser extends TasksEvent {
  final String userEmail;

  const FilterByAssignedUser({required this.userEmail});

  @override
  List<Object> get props => [userEmail];
}

class LoadTasksByPage extends TasksEvent {
  final int limit;
  final Task? lastTask;
  final String? status;
  final String? projectName;

  const LoadTasksByPage({
    this.limit = 10,
    this.lastTask,
    this.status,
    this.projectName,
  });

  @override
  List<Object> get props => [
    limit,
    if (status != null) status as Object,
    if (projectName != null) projectName as Object,
  ];
}

// States
abstract class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object> get props => [];
}

class TasksInitial extends TasksState {}

class TasksLoading extends TasksState {}

class TasksLoaded extends TasksState {
  final List<Task> tasks;
  final bool hasMoreTasks;
  final Task? lastTask;

  const TasksLoaded({
    required this.tasks, 
    this.hasMoreTasks = false,
    this.lastTask,
  });

  @override
  List<Object> get props => [tasks, hasMoreTasks];
}

class TasksError extends TasksState {
  final String message;

  const TasksError({required this.message});

  @override
  List<Object> get props => [message];
}

// BLoC
class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TaskRepository taskRepository;

  TasksBloc(this.taskRepository) : super(TasksInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTaskStatus>(_onUpdateTaskStatus);
    on<FilterByStatus>(_onFilterByStatus);
    on<FilterByProject>(_onFilterByProject);
    on<FilterByDate>(_onFilterByDate);
    on<FilterByAssignedUser>(_onFilterByAssignedUser);
    on<LoadTasksByPage>(_onLoadTasksByPage);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final tasks = await taskRepository.getTasks();
      emit(TasksLoaded(tasks: tasks));
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }

  Future<void> _onAddTask(AddTask event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      await taskRepository.addTask(
        title: event.title,
        description: event.description,
        deadlineDate: event.deadlineDate,
        deadlineTime: event.deadlineTime,
        members: event.members,
        projectName: event.projectName,
      );
      final tasks = await taskRepository.getTasks();
      emit(TasksLoaded(tasks: tasks));
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }

  Future<void> _onUpdateTaskStatus(UpdateTaskStatus event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      await taskRepository.updateTaskStatus(
        taskId: event.taskId,
        status: event.status,
      );
      final tasks = await taskRepository.getTasks();
      emit(TasksLoaded(tasks: tasks));
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }

  Future<void> _onFilterByStatus(FilterByStatus event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final tasks = await taskRepository.getTasksByStatus(event.status);
      emit(TasksLoaded(tasks: tasks));
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }

  Future<void> _onFilterByProject(FilterByProject event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final tasks = await taskRepository.getTasksByProject(event.projectName);
      emit(TasksLoaded(tasks: tasks));
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }
  
  Future<void> _onFilterByDate(FilterByDate event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      // Format the date as dd/MM/yyyy to match the format in the tasks
      final day = event.date.day.toString().padLeft(2, '0');
      final month = event.date.month.toString().padLeft(2, '0');
      final year = event.date.year.toString();
      final dateString = '$day/$month/$year';
      
      print('Lọc task theo ngày: $dateString');
      
      // Lấy tất cả task trước
      final allTasks = await taskRepository.getTasks();
      
      // Tìm task cho ngày đã chọn
      final tasksForDay = allTasks.where((task) => task.deadlineDate == dateString).toList();
      
      // Kiểm tra xem ngày đã chọn có phải là ngày hiện tại hoặc trong quá khứ không
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDate = event.date;
      
      // Nếu không tìm thấy task cho ngày đã chọn, tìm các task quá hạn
      // Bỏ điều kiện isPastOrToday để hiển thị task quá hạn cho cả ngày trong tương lai
      if (tasksForDay.isEmpty) {
        print('Không tìm thấy task cho ngày $dateString, kiểm tra task quá hạn...');
        
        final overdueTasks = allTasks.where((task) {
          try {
            // Chuyển đổi deadline của task thành DateTime
            final parts = task.deadlineDate.split('/');
            if (parts.length == 3) {
              final taskDay = int.parse(parts[0]);
              final taskMonth = int.parse(parts[1]);
              final taskYear = int.parse(parts[2]);
              final taskDate = DateTime(taskYear, taskMonth, taskDay);
              
              // Task quá hạn nếu deadline trước ngày hiện tại và chưa hoàn thành
              final isOverdue = taskDate.isBefore(today) && 
                              task.status.toLowerCase() != 'completed' &&
                              task.status.toLowerCase() != 'hoàn thành';
              
              if (isOverdue) {
                print('Task quá hạn: ${task.title}, Deadline: ${task.deadlineDate}, Status: ${task.status}');
              }
              
              return isOverdue;
            }
          } catch (e) {
            print('Lỗi khi phân tích ngày: $e');
          }
          return false;
        }).toList();
        
        print('Tìm thấy ${overdueTasks.length} task quá hạn');
        
        // Nếu có task quá hạn, trả về danh sách đó
        if (overdueTasks.isNotEmpty) {
          emit(TasksLoaded(tasks: overdueTasks));
          return;
        }
      }
      
      // Nếu có task cho ngày đã chọn hoặc không có task quá hạn, trả về kết quả từ repository
      final filteredTasks = await taskRepository.getTasksByDate(dateString);
      emit(TasksLoaded(tasks: filteredTasks));
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }

  Future<void> _onFilterByAssignedUser(FilterByAssignedUser event, Emitter<TasksState> emit) async {
    emit(TasksLoading());
    try {
      final filteredTasks = await taskRepository.getTasksByAssignedUser(event.userEmail);
      emit(TasksLoaded(tasks: filteredTasks));
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }
  
  Future<void> _onLoadTasksByPage(LoadTasksByPage event, Emitter<TasksState> emit) async {
    try {
      // Nếu đang ở trạng thái TasksLoaded, giữ lại danh sách task hiện tại
      final currentState = state;
      List<Task> currentTasks = [];
      
      if (currentState is TasksLoaded) {
        currentTasks = currentState.tasks;
        
        // Nếu đang tải trang đầu tiên, hiển thị trạng thái loading
        if (event.lastTask == null) {
          emit(TasksLoading());
        }
      } else {
        emit(TasksLoading());
      }
      
      // Tải task theo trang
      final newTasks = await taskRepository.getTasksByPage(
        limit: event.limit,
        lastTask: event.lastTask,
        status: event.status,
        projectName: event.projectName,
      );
      
      // Nếu đang tải trang tiếp theo, kết hợp với danh sách hiện tại
      if (event.lastTask != null && currentState is TasksLoaded) {
        final combinedTasks = [...currentTasks, ...newTasks];
        
        // Kiểm tra xem còn task nào để tải không
        final hasMore = newTasks.length >= event.limit;
        
        emit(TasksLoaded(
          tasks: combinedTasks,
          hasMoreTasks: hasMore,
          lastTask: newTasks.isNotEmpty ? newTasks.last : null,
        ));
      } else {
        // Nếu đang tải trang đầu tiên, chỉ hiển thị task mới
        final hasMore = newTasks.length >= event.limit;
        
        emit(TasksLoaded(
          tasks: newTasks,
          hasMoreTasks: hasMore,
          lastTask: newTasks.isNotEmpty ? newTasks.last : null,
        ));
      }
    } catch (e) {
      emit(TasksError(message: e.toString()));
    }
  }
} 