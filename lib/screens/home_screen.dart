import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mission_master/Utils/utils.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/events.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/bloc/HomePageTaskTabsBloc/bloc.dart';
import 'package:mission_master/bloc/HomePageTaskTabsBloc/events.dart';
import 'package:mission_master/bloc/HomePageTaskTabsBloc/states.dart';
import 'package:mission_master/bloc/userBloc/bloc.dart';
import 'package:mission_master/bloc/userBloc/events.dart';
import 'package:mission_master/bloc/userBloc/states.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/labels.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/notification/notification_services.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/widgets/task_card.dart';
import 'package:mission_master/widgets/task_tile.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/workspace_container.dart';
import 'package:mission_master/widgets/ai_priority_widget.dart';
import 'package:mission_master/services/task_priority_ai.dart';
import 'package:mission_master/bloc/tasks/tasks_bloc.dart' as tasks_bloc;
import 'package:mission_master/screens/task/task_detail_screen.dart';
import 'package:table_calendar/table_calendar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final projectController = ProjectController();
  final GlobalKey<AnimatedListState> listKey = GlobalKey();
  var project = locator<Database>;
  NotificationServices notification = NotificationServices();
  int colorIndex1 = 0;
  int colorIndex2 = 0;
  
  // Calendar và filtering
  late TabController _tabController;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  String _selectedStatus = 'all';

  @override
  void initState() {
    notification.requestPermission();
    notification.firebaseinit(context);
    notification.setupInteractMessage(context);
    _tabController = TabController(length: 3, vsync: this);
    
    // Đặt ngày mặc định là ngày hiện tại
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _focusedDay = DateTime(now.year, now.month, now.day);
    
    // Đồng bộ dữ liệu từ Firebase trước khi tải tasks
    final tasksBloc = context.read<tasks_bloc.TasksBloc>();
    tasksBloc.taskRepository.syncTasksFromFirebase().then((_) {
      // Sau khi đồng bộ, tải tasks theo trang
      tasksBloc.add(tasks_bloc.LoadTasksByPage(limit: 10));
    });
    
    super.initState();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar sẽ được hiển thị dưới AppBar của MainScreen
        Container(
          color: AppColors.primaryColor,
          child: TabBar(
                      controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Nhiệm vụ của tôi'),
              Tab(text: 'Theo dự án'),
              Tab(text: 'Lịch'),
            ],
            onTap: (index) {
              if (index == 0) {
                // Tab "Tất cả" - CHỈ HIỂN THỊ TASK ĐƯỢC GIAO CHO USER HIỆN TẠI
                final tasksBloc = context.read<tasks_bloc.TasksBloc>();
                tasksBloc.taskRepository.syncTasksFromFirebase().then((_) {
                  tasksBloc.add(
                    tasks_bloc.LoadTasksByPage(
                      limit: 10,
                      status: _selectedStatus == 'all' ? null : _selectedStatus,
                    )
                  );
                });
              } else if (index == 1) {
                // Tab "Theo dự án" - Có thể filter theo specific project
                final tasksBloc = context.read<tasks_bloc.TasksBloc>();
                tasksBloc.taskRepository.syncTasksFromFirebase().then((_) {
                  tasksBloc.add(
                    tasks_bloc.LoadTasksByPage(
                      limit: 10,
                      status: _selectedStatus == 'all' ? null : _selectedStatus,
                    )
                  );
                });
              } else if (index == 2) {
                // Khi chuyển sang tab Lịch, đảm bảo hiển thị đúng các task của ngày đã chọn
                final tasksBloc = context.read<tasks_bloc.TasksBloc>();
                tasksBloc.taskRepository.syncTasksFromFirebase().then((_) {
                  tasksBloc.add(tasks_bloc.FilterByDate(date: _selectedDay));
                });
              }
            },
          ),
        ),
        // Body content
        Expanded(
          child: Container(
            color: AppColors.background,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskListView(),
                _buildAssignedTasksView(),
                _buildCalendarView(),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  void _filterTasks(String status) {
    setState(() {
      _selectedStatus = status;
    });
    
    // Sử dụng LoadTasksByPage thay vì LoadTasks để đảm bảo chỉ lấy task của user hiện tại
    final tasksBloc = context.read<tasks_bloc.TasksBloc>();
    tasksBloc.taskRepository.syncTasksFromFirebase().then((_) {
      tasksBloc.add(
        tasks_bloc.LoadTasksByPage(
          limit: 10,
          status: status == 'all' ? null : status,
        )
      );
    });
  }
  
  List<Task> _getTasksForSelectedDay(List<Task> allTasks) {
    // Format the selected date to match the format in tasks (dd/MM/yyyy)
    final day = _selectedDay.day.toString().padLeft(2, '0');
    final month = _selectedDay.month.toString().padLeft(2, '0');
    final year = _selectedDay.year.toString();
    final selectedDateString = '$day/$month/$year';
    
    print('Đang lọc task cho ngày: $selectedDateString');
    
    // Lọc các task có deadline trùng với ngày đã chọn
    final filteredTasks = allTasks.where((task) {
      
      // So sánh trực tiếp chuỗi ngày tháng
      final matches = task.deadlineDate == selectedDateString;
      if (matches) {
        print('Tìm thấy task cho ngày $selectedDateString: ${task.title}');
      }
      return matches;
    }).toList();
    
    print('Tổng số task tìm thấy cho ngày $selectedDateString: ${filteredTasks.length}');
    
    // Kiểm tra xem ngày đã chọn có phải là ngày hiện tại hoặc trong quá khứ không
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Nếu không tìm thấy task nào cho ngày đã chọn, hiển thị các task quá hạn
    // Bỏ điều kiện isPastOrToday để hiển thị task quá hạn cho cả ngày trong tương lai
    if (filteredTasks.isEmpty) {
      print('Kiểm tra các task quá hạn cho ngày $selectedDateString...');
      
      // Tìm các task quá hạn
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
          print('Lỗi khi phân tích ngày của task ${task.title}: $e');
        }
        return false;
      }).toList();
      
      print('Tìm thấy ${overdueTasks.length} task quá hạn');
      
      // Nếu có task quá hạn, trả về danh sách đó
      if (overdueTasks.isNotEmpty) {
        return overdueTasks;
      }
    }
    
    return filteredTasks;
  }
  
  Widget _buildTaskListView() {
    return BlocBuilder<tasks_bloc.TasksBloc, tasks_bloc.TasksState>(
      builder: (context, state) {
        if (state is tasks_bloc.TasksLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is tasks_bloc.TasksLoaded) {
          final tasks = state.tasks;
          
          if (tasks.isEmpty) {
            return _buildEmptyState();
          }
          
          // Tích hợp AI Top Priority
          return _buildTaskListWithAI(tasks);
        } else if (state is tasks_bloc.TasksError) {
          return Center(child: Text('Lỗi: ${state.message}'));
        }
        
        // Initial state
        return _buildWelcomeScreen();
      },
    );
  }

  Widget _buildTaskListWithAI(List<Task> tasks) {
    // Lấy top priority tasks bằng AI
    final topPriorityTasks = TaskPriorityAI.getTopPriorityTasks(tasks, limit: 3);
    
    return Column(
      children: [
        // AI Top Priority Section
        if (topPriorityTasks.isNotEmpty)
          AITopTasksWidget(
            tasks: topPriorityTasks,
            onSeeAll: () {
              // Navigate to full AI prioritized list
              _showAIPrioritizedTasks(tasks);
            },
          ),
        
        // Regular task list
        Expanded(
          child: _buildTaskList(tasks),
        ),
      ],
    );
  }

  void _showAIPrioritizedTasks(List<Task> allTasks) {
    final prioritizedTasks = TaskPriorityAI.sortTasksBySmartPriority(allTasks);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🤖 AI sắp xếp tất cả nhiệm vụ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: prioritizedTasks.length,
                    itemBuilder: (context, index) {
                      final task = prioritizedTasks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(task.title),
                          subtitle: Text('📅 ${task.deadlineDate}'),
                          trailing: AIPriorityWidget(
                            task: task,
                            compact: true,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskDetailScreen(task: task),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssignedTasksView() {
    // Tab "Theo dự án" - có thể thêm dropdown để filter theo specific project
    return BlocBuilder<tasks_bloc.TasksBloc, tasks_bloc.TasksState>(
      builder: (context, state) {
        if (state is tasks_bloc.TasksLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is tasks_bloc.TasksLoaded) {
          final tasks = state.tasks;
          final hasMoreTasks = state.hasMoreTasks;
          final lastTask = state.lastTask;
          
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn chưa được giao công việc nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Các công việc được giao cho bạn sẽ hiển thị ở đây',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: hasMoreTasks ? tasks.length + 1 : tasks.length,
                  itemBuilder: (context, index) {
                    // Nếu đến cuối danh sách và còn task chưa hiển thị, hiện nút "Tải thêm"
                    if (hasMoreTasks && index == tasks.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              // Tải thêm task
                              context.read<tasks_bloc.TasksBloc>().add(
                                tasks_bloc.LoadTasksByPage(
                                  limit: 10,
                                  lastTask: lastTask,
                                  status: _selectedStatus == 'all' ? null : _selectedStatus,
                                ),
                              );
                            },
                            child: const Text('Tải thêm'),
                          ),
                        ),
                      );
                    }
                    
                    // Hiển thị task bình thường
                    final task = tasks[index];
                    return TaskCard(
                      task: task,
                      onTap: () => _showTaskDetails(task),
                    );
                  },
                ),
              ),
              
              // Hiển thị thông tin về số lượng task
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Hiển thị ${tasks.length} task',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          );
        }
        
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
  
  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; // Cập nhật focusedDay để tháng hiển thị đúng
              });
              
              // Đồng bộ dữ liệu từ Firebase trước khi lọc theo ngày
              final tasksBloc = context.read<tasks_bloc.TasksBloc>();
              tasksBloc.taskRepository.syncTasksFromFirebase().then((_) {
                // Filter tasks by the selected date
                tasksBloc.add(tasks_bloc.FilterByDate(date: selectedDay));
              });
            }
          },
          onPageChanged: (focusedDay) {
            // Cập nhật focusedDay khi người dùng chuyển tháng mà không thay đổi ngày đã chọn
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primaryColor,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: AppColors.accentColor,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonTextStyle: TextStyle(fontSize: 14),
            formatButtonDecoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: BlocBuilder<tasks_bloc.TasksBloc, tasks_bloc.TasksState>(
            builder: (context, state) {
              if (state is tasks_bloc.TasksLoaded) {
                final tasksForDay = _getTasksForSelectedDay(state.tasks);
                
                if (tasksForDay.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có nhiệm vụ cho ngày ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Chuyển đến màn hình thêm task với ngày đã chọn
                            Navigator.pushNamed(context, AppRoutes.addTask);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm công việc mới'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Kiểm tra xem có đang hiển thị task quá hạn không
                final bool showingOverdueTasks = tasksForDay.any((task) {
                  try {
                    final parts = task.deadlineDate.split('/');
                    if (parts.length == 3) {
                      final taskDay = int.parse(parts[0]);
                      final taskMonth = int.parse(parts[1]);
                      final taskYear = int.parse(parts[2]);
                      final taskDate = DateTime(taskYear, taskMonth, taskDay);
                      
                      return taskDate.isBefore(_selectedDay) && 
                             task.status.toLowerCase() != 'completed' &&
                             task.status.toLowerCase() != 'hoàn thành';
                    }
                  } catch (e) {
                    // Bỏ qua lỗi
                  }
                  return false;
                });
                
                return Column(
                  children: [
                    // Hiển thị banner khi đang xem các task quá hạn
                    if (showingOverdueTasks)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        color: Colors.amber.shade100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hiển thị các nhiệm vụ quá hạn cần hoàn thành',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đây là các nhiệm vụ đã quá hạn và chưa hoàn thành. Hãy cập nhật trạng thái hoặc hoàn thành chúng sớm.',
                              style: TextStyle(
                                color: Colors.amber.shade800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: Icon(Icons.calendar_today, size: 16, color: Colors.amber.shade900),
                                  label: Text(
                                    'Xem lịch hôm nay',
                                    style: TextStyle(color: Colors.amber.shade900),
                                  ),
                                  onPressed: () {
                                    // Chuyển về ngày hiện tại
                                    final now = DateTime.now();
                                    setState(() {
                                      _selectedDay = DateTime(now.year, now.month, now.day);
                                      _focusedDay = DateTime(now.year, now.month, now.day);
                                    });
                                    
                                    // Lọc task theo ngày hiện tại
                                    context.read<tasks_bloc.TasksBloc>().add(
                                      tasks_bloc.FilterByDate(date: _selectedDay)
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tasksForDay.length,
                        itemBuilder: (context, index) {
                          final task = tasksForDay[index];
                          return TaskCard(
                            task: task,
                            onTap: () => _showTaskDetails(task),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined, 
            size: 80, 
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có công việc nào',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy thêm công việc đầu tiên của bạn',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.addTask);
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm công việc'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskList(List<Task> tasks) {
    // Sắp xếp task theo deadline
    tasks.sort((a, b) {
      // Chuyển đổi định dạng ngày dd/MM/yyyy thành DateTime để so sánh
      try {
        final aParts = a.deadlineDate.split('/');
        final bParts = b.deadlineDate.split('/');
        
        if (aParts.length == 3 && bParts.length == 3) {
          final aDate = DateTime(
            int.parse(aParts[2]), 
            int.parse(aParts[1]), 
            int.parse(aParts[0])
          );
          
          final bDate = DateTime(
            int.parse(bParts[2]), 
            int.parse(bParts[1]), 
            int.parse(bParts[0])
          );
          
          return aDate.compareTo(bDate);
        }
      } catch (e) {
        print('Lỗi khi sắp xếp task: $e');
      }
      
      // Nếu không thể so sánh ngày, giữ nguyên thứ tự
      return 0;
    });
    
    // Số lượng task hiển thị ban đầu
    const int initialLoadCount = 10;
    // Số lượng task tải thêm mỗi lần
    const int loadMoreCount = 10;
    
    return StatefulBuilder(
      builder: (context, setState) {
        // Số lượng task hiện tại đang hiển thị
        final ValueNotifier<int> displayCount = ValueNotifier<int>(
          tasks.length > initialLoadCount ? initialLoadCount : tasks.length
        );
        
        return Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: displayCount,
                builder: (context, count, child) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
                    itemCount: count < tasks.length ? count + 1 : count, // +1 cho nút "Tải thêm"
      itemBuilder: (context, index) {
                      // Nếu đến cuối danh sách và còn task chưa hiển thị, hiện nút "Tải thêm"
                      if (index == count && count < tasks.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                // Tăng số lượng task hiển thị
                                final newCount = count + loadMoreCount;
                                displayCount.value = newCount > tasks.length ? tasks.length : newCount;
                              },
                              child: Text('Tải thêm (${tasks.length - count} task còn lại)'),
                            ),
                          ),
                        );
                      }
                      
                      // Hiển thị task bình thường
        final task = tasks[index];
        return TaskCard(
          task: task,
          onTap: () => _showTaskDetails(task),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Hiển thị thông tin tổng số task
            if (tasks.length > initialLoadCount)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ValueListenableBuilder<int>(
                  valueListenable: displayCount,
                  builder: (context, count, _) {
                    return Text(
                      'Hiển thị $count / ${tasks.length} task',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    );
                  }
                ),
              ),
          ],
        );
      },
    );
  }
  
  void _showTaskDetails(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(task: task),
      ),
    );
  }
  
  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Chào mừng đến với Mission Master',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Giải pháp quản lý công việc của bạn',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Load tasks when button is pressed
              context.read<tasks_bloc.TasksBloc>().add(tasks_bloc.LoadTasks());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }
  
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Hoàn thành';
      case 'in progress':
        return 'Đang thực hiện';
      default:
        return 'Chờ xử lý';
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.taskCompleted;
      case 'in progress':
        return AppColors.taskInProgress;
      default:
        return AppColors.taskPending;
    }
  }
  
  // Hiển thị dialog lọc nhiệm vụ
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc nhiệm vụ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Tất cả'),
              onTap: () {
                Navigator.pop(context);
                _filterTasks('all');
              },
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: const Text('Chờ xử lý'),
              onTap: () {
                Navigator.pop(context);
                _filterTasks('none');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timelapse),
              title: const Text('Đang thực hiện'),
              onTap: () {
                Navigator.pop(context);
                _filterTasks('in progress');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Hoàn thành'),
              onTap: () {
                Navigator.pop(context);
                _filterTasks('completed');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
  
  // Xóa dữ liệu cục bộ và đồng bộ lại từ Firebase
  void _clearLocalCache() {
    // Hiển thị dialog xác nhận
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa dữ liệu cục bộ'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa tất cả dữ liệu cục bộ và đồng bộ lại từ Firebase không?\n\n'
          'Điều này có thể giúp khắc phục các vấn đề hiển thị dữ liệu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Hiển thị thông báo đang xóa
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đang xóa dữ liệu cục bộ...'),
                  duration: Duration(seconds: 1),
                ),
              );
              
              // Xóa dữ liệu cục bộ và đồng bộ lại
              final tasksBloc = context.read<tasks_bloc.TasksBloc>();
              tasksBloc.taskRepository.clearLocalTasks().then((_) {
                // Sau khi đồng bộ, tải lại dữ liệu
                tasksBloc.add(tasks_bloc.LoadTasks());
                
                // Hiển thị thông báo đã xóa
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa dữ liệu cục bộ và đồng bộ lại thành công'),
                    backgroundColor: Colors.green,
                  ),
                );
              }).catchError((error) {
                // Hiển thị thông báo lỗi
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
