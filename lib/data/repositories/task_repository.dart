import 'dart:async';
import 'dart:isolate';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:mission_master/services/task_priority_ai.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';

class TaskRepository {
  final TaskDataProvider taskDataProvider;
  final _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSyncing = false;
  
  // Stream controller để thông báo khi đồng bộ hoàn tất
  final StreamController<bool> _syncController = StreamController<bool>.broadcast();
  Stream<bool> get syncStream => _syncController.stream;

  TaskRepository({required this.taskDataProvider});

  Future<List<Task>> getTasks() async {
    try {
      // Lấy dữ liệu từ SharedPreferences
      final localTasks = await taskDataProvider.getTasks();
      print('Lấy ${localTasks.length} task từ bộ nhớ cục bộ');
      
      // Kiểm tra xem có cần đồng bộ không
      if (taskDataProvider.needsSync()) {
        // Đồng bộ trong nền nếu có dữ liệu cục bộ
        if (localTasks.isNotEmpty) {
          _startBackgroundSync();
          return localTasks; // Trả về dữ liệu cục bộ ngay lập tức
        } else {
          // Nếu không có dữ liệu cục bộ, đồng bộ ngay
          await syncTasksFromFirebase();
          return await taskDataProvider.getTasks();
        }
      }
      
      return localTasks;
    } catch (e) {
      print('Error fetching tasks: $e');
      // Nếu có lỗi, trả về dữ liệu local
    return await taskDataProvider.getTasks();
    }
  }

  // Khởi động đồng bộ trong nền
  void _startBackgroundSync() {
    if (!_isSyncing) {
      _isSyncing = true;
      Future.microtask(() async {
        try {
          await syncTasksFromFirebase();
        } finally {
          _isSyncing = false;
          _syncController.add(true); // Thông báo đồng bộ hoàn tất
        }
      });
    }
  }

  Future<void> addTask({
    required String title,
    required String description,
    required String deadlineDate,
    required String deadlineTime,
    required List<String> members,
    required String projectName,
  }) async {
    final tasks = await taskDataProvider.getTasks();
    
    final newTask = Task(
      id: _uuid.v4(),
      title: title,
      description: description,
      deadlineDate: deadlineDate,
      deadlineTime: deadlineTime,
      members: members,
      status: 'none',
      projectName: projectName,
      projectId: _uuid.v4(),
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
    );
    
    tasks.add(newTask);
    await taskDataProvider.saveTasks(tasks);
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final tasks = await taskDataProvider.getTasks();
    final index = tasks.indexWhere((task) => task.id == taskId);
    
    if (index != -1) {
      tasks[index] = tasks[index].copyWith(
        status: status,
        lastModified: DateTime.now(),
      );
      await taskDataProvider.saveTasks(tasks);
    }
  }

  Future<List<Task>> getTasksByStatus(String status) async {
    final tasks = await taskDataProvider.getTasks();
    return tasks.where((task) => task.status == status).toList();
  }

  Future<List<Task>> getTasksByProject(String projectName) async {
    final tasks = await taskDataProvider.getTasks();
    return tasks.where((task) => task.projectName == projectName).toList();
  }

  Future<List<Task>> getTasksByDate(String dateString) async {
    final tasks = await taskDataProvider.getTasks();
    return tasks.where((task) => task.deadlineDate == dateString).toList();
  }

  Future<List<Task>> getTasksByAssignedUser(String userEmail) async {
    try {
      // Lấy tất cả các task đã được đồng bộ
      final tasks = await getTasks();
      
      print('Tìm task được gán cho người dùng: $userEmail');
      print('Tổng số task có sẵn: ${tasks.length}');
      
      // Lọc các task có chứa email người dùng trong danh sách members
      final assignedTasks = tasks.where((task) {
        final isAssigned = task.members.contains(userEmail);
        if (isAssigned) {
          print('Task được gán cho $userEmail: ${task.title}, members: ${task.members}');
        }
        return isAssigned;
      }).toList();
      
      print('Tìm thấy ${assignedTasks.length} task được gán cho người dùng $userEmail');
      return assignedTasks;
    } catch (e) {
      print('Error filtering tasks by assigned user: $e');
      // Nếu có lỗi, trả về danh sách rỗng
      return [];
    }
  }

  /// 🤖 AI: Lấy tasks đã được sắp xếp theo độ ưu tiên thông minh
  Future<List<Task>> getTasksWithSmartPriority({String? userEmail}) async {
    try {
      List<Task> tasks;
      
      if (userEmail != null) {
        tasks = await getTasksByAssignedUser(userEmail);
      } else {
        tasks = await getTasks();
      }
      
      // Sử dụng AI để sắp xếp tasks
      final prioritizedTasks = TaskPriorityAI.sortTasksBySmartPriority(tasks);
      
      print('🤖 AI sắp xếp ${prioritizedTasks.length} tasks theo độ ưu tiên thông minh');
      
      return prioritizedTasks;
    } catch (e) {
      print('Error getting smart prioritized tasks: $e');
      return await getTasks();
    }
  }

  /// 🔥 AI: Lấy top tasks ưu tiên cao nhất
  Future<List<Task>> getTopPriorityTasks({String? userEmail, int limit = 5}) async {
    try {
      List<Task> tasks;
      
      if (userEmail != null) {
        tasks = await getTasksByAssignedUser(userEmail);
      } else {
        tasks = await getTasks();
      }
      
      final topTasks = TaskPriorityAI.getTopPriorityTasks(tasks, limit: limit);
      
      print('🔥 AI tìm ${topTasks.length} tasks ưu tiên cao nhất');
      
      return topTasks;
    } catch (e) {
      print('Error getting top priority tasks: $e');
      return [];
    }
  }

  Task _convertToTask(String id, Map<String, dynamic> data) {
    // In ra dữ liệu để debug
    print('Converting task data: $id');
    print('Task name: ${data['taskName']}');
    print('Members: ${data['Members']}');
    
    List<String> members = [];
    if (data['Members'] != null) {
      if (data['Members'] is List) {
        members = List<String>.from(data['Members']);
      } else if (data['Members'] is String) {
        // Nếu Members là một chuỗi đơn, chuyển thành danh sách
        members = [data['Members'] as String];
      }
    }
    
    // Lấy timestamp từ Firestore nếu có
    DateTime? createdAt;
    DateTime? lastModified;
    
    if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
      createdAt = (data['timestamp'] as Timestamp).toDate();
    }
    
    if (data['lastModified'] != null && data['lastModified'] is Timestamp) {
      lastModified = (data['lastModified'] as Timestamp).toDate();
    } else if (createdAt != null) {
      lastModified = createdAt; // Nếu không có lastModified, sử dụng thời gian tạo
    }
    
    return Task(
      id: id,
      title: data['taskName'] ?? '',
      description: data['description'] ?? '',
      deadlineDate: data['deadlineDate'] ?? '',
      deadlineTime: data['deadlineTime'] ?? '',
      members: members,
      status: data['status'] ?? 'none',
      projectName: data['projectName'] ?? '',
      projectId: data['projectId'] ?? id.split('/')[0],
      priority: data['priority'] ?? 'normal',
      isRecurring: data['isRecurring'] ?? false,
      recurringInterval: data['recurringInterval'] ?? '',
      createdAt: createdAt,
      lastModified: lastModified,
    );
  }

  // Đồng bộ dữ liệu từ Firebase vào SharedPreferences
  Future<void> syncTasksFromFirebase() async {
    try {
      final String currentUserEmail = Auth.auth.currentUser?.email ?? '';
      if (currentUserEmail.isEmpty) {
        print('Không thể đồng bộ: Người dùng chưa đăng nhập');
        return; // Nếu chưa đăng nhập, không làm gì cả
      }
      
      print('Bắt đầu đồng bộ dữ liệu từ Firebase cho người dùng: $currentUserEmail');
      
      // Lấy thời gian đồng bộ cuối cùng để đồng bộ gia tăng
      final DateTime? lastSync = taskDataProvider.getLastSyncTime();
      print('Thời gian đồng bộ cuối cùng: ${lastSync?.toIso8601String() ?? "Chưa từng đồng bộ"}');
      
      // Lấy tất cả các project mà người dùng tham gia
      final QuerySnapshot projectsSnapshot = await _firestore
          .collection('Project')
          .where(Filter.or(
            Filter("email", arrayContains: currentUserEmail),
            Filter("projectCreatedBy", isEqualTo: currentUserEmail)
          ))
          .get();
          
      print('Tìm thấy ${projectsSnapshot.docs.length} dự án');
      
      // Lấy tasks hiện có từ SharedPreferences
      final localTasks = await taskDataProvider.getTasks();
      print('Số task trong bộ nhớ cục bộ: ${localTasks.length}');
      
      // Tạo map từ id đến task để dễ dàng cập nhật
      final Map<String, Task> localTaskMap = {
        for (var task in localTasks) task.id: task
      };
      
      // Duyệt qua từng project để lấy tasks
      for (var projectDoc in projectsSnapshot.docs) {
        final String projectId = projectDoc.id;
        final projectData = projectDoc.data() as Map<String, dynamic>;
        final String projectName = projectData['projectName'] as String? ?? 'Dự án không tên';
        
        print('Đang lấy task từ dự án: $projectName (ID: $projectId)');
        
        // Kiểm tra cache trước
        final cachedTasks = await taskDataProvider.getCachedTasks(projectId);
        if (cachedTasks.isNotEmpty) {
          print('Sử dụng ${cachedTasks.length} task từ cache cho dự án $projectName');
          
          // Cập nhật từ cache vào map
          for (var task in cachedTasks) {
            localTaskMap[task.id] = task;
          }
          
          // Tiếp tục với dự án tiếp theo nếu cache hợp lệ
          continue;
        }
        
        // Tạo query để lấy tasks - CHỈ LẤY TASK ĐƯỢC GIAO CHO USER HIỆN TẠI
        Query query = _firestore
            .collection('Tasks')
            .doc(projectId)
            .collection('projectTasks')
            .where('Members', arrayContains: currentUserEmail);
            
        if (lastSync != null) {
          // Chỉ lấy các task đã được cập nhật sau lần đồng bộ cuối cùng
          query = query.where('lastModified', isGreaterThan: lastSync);
        }
        
        final QuerySnapshot taskSnapshot = await query.get();
        print('Tìm thấy ${taskSnapshot.docs.length} task cần đồng bộ trong dự án $projectName');
        
        final List<Task> projectTasks = [];
        
        for (var doc in taskSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          // In thông tin chi tiết về task
          print('Task ID: ${doc.id}');
          print('Task Name: ${data['taskName']}');
          
          // Chuyển đổi thành Task object
          final task = _convertToTask(doc.id, data);
          projectTasks.add(task);
          
          // Cập nhật vào map
          localTaskMap[task.id] = task;
        }
        
        // Lưu cache cho dự án này
        if (projectTasks.isNotEmpty) {
          await taskDataProvider.saveProjectTasksCache(projectId, projectTasks);
          print('Đã lưu cache cho dự án $projectName với ${projectTasks.length} task');
        }
      }
      
      // Chuyển map trở lại thành danh sách và lưu
      final allTasks = localTaskMap.values.toList();
      await taskDataProvider.saveTasks(allTasks);
      
      // Lưu thời gian đồng bộ
      await taskDataProvider.saveLastSyncTime(DateTime.now());
      
      print('Đồng bộ hoàn tất: tổng cộng ${allTasks.length} task');
    } catch (e) {
      print('Error syncing tasks from Firebase: $e');
    }
  }

  // Xóa dữ liệu cục bộ và buộc đồng bộ lại từ Firebase
  Future<void> clearLocalTasks() async {
    try {
      // Xóa dữ liệu cục bộ
      await taskDataProvider.saveTasks([]);
      await taskDataProvider.clearCache();
      print('Đã xóa tất cả dữ liệu cục bộ');
      
      // Đồng bộ lại từ Firebase
      await syncTasksFromFirebase();
    } catch (e) {
      print('Error clearing local tasks: $e');
    }
  }

  // Lấy task theo trang (pagination) cho người dùng hiện tại
  Future<List<Task>> getTasksByPage({
    int limit = 10,
    Task? lastTask,
    String? status,
    String? projectName,
  }) async {
    try {
      final String currentUserEmail = Auth.auth.currentUser?.email ?? '';
      if (currentUserEmail.isEmpty) {
        print('Không thể tải task: Người dùng chưa đăng nhập');
        return [];
      }
      
      print('Tải task theo trang cho người dùng: $currentUserEmail');
      print('Giới hạn: $limit, Trạng thái: ${status ?? "tất cả"}, Dự án: ${projectName ?? "tất cả"}');
      
      // Lấy tất cả các task từ bộ nhớ cục bộ (đã được đồng bộ từ Firebase)
      final allTasks = await taskDataProvider.getTasks();
      
      // Lọc task theo điều kiện
      List<Task> filteredTasks = allTasks.where((task) {
        // Lọc theo người dùng được gán
        final isAssigned = task.members.contains(currentUserEmail);
        
        // Lọc theo trạng thái nếu có
        final matchesStatus = status == null || task.status == status;
        
        // Lọc theo dự án nếu có
        final matchesProject = projectName == null || task.projectName == projectName;
        
        return isAssigned && matchesStatus && matchesProject;
      }).toList();
      
      // Sắp xếp theo deadline
      filteredTasks.sort((a, b) {
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
        
        return 0;
      });
      
      // Nếu có task cuối cùng, tìm vị trí của nó để lấy trang tiếp theo
      if (lastTask != null) {
        final lastIndex = filteredTasks.indexWhere((t) => t.id == lastTask.id);
        if (lastIndex != -1 && lastIndex < filteredTasks.length - 1) {
          // Lấy các task từ vị trí sau task cuối cùng
          filteredTasks = filteredTasks.sublist(lastIndex + 1);
        }
      }
      
      // Giới hạn số lượng task trả về
      if (filteredTasks.length > limit) {
        filteredTasks = filteredTasks.sublist(0, limit);
      }
      
      print('Đã tải ${filteredTasks.length} task theo trang');
      return filteredTasks;
    } catch (e) {
      print('Lỗi khi tải task theo trang: $e');
      return [];
    }
  }
  
  // Đóng stream controller khi không cần thiết nữa
  void dispose() {
    _syncController.close();
  }

  // Lấy nhiệm vụ theo ID dự án
  Future<List<Task>> getTasksByProjectId(String projectId) async {
    try {
      return await taskDataProvider.getTasksByProject(projectId);
    } catch (e) {
      print('Lỗi khi lấy nhiệm vụ theo dự án: $e');
      return [];
    }
  }
  
  // Lấy danh sách thành viên dự án
  Future<List<String>> getProjectMembers(String projectId) async {
    try {
      return await taskDataProvider.getProjectMembers(projectId);
    } catch (e) {
      print('Lỗi khi lấy danh sách thành viên: $e');
      return [];
    }
  }
  
  // Tạo nhiệm vụ mới
  Future<bool> createTask(Task task) async {
    try {
      await taskDataProvider.createTask(task);
      return true;
    } catch (e) {
      print('Lỗi khi tạo nhiệm vụ: $e');
      return false;
    }
  }
  
  // Cập nhật nhiệm vụ
  Future<bool> updateTask(Task task) async {
    try {
      await taskDataProvider.updateTask(task);
      return true;
    } catch (e) {
      print('Lỗi khi cập nhật nhiệm vụ: $e');
      return false;
    }
  }
  
  // Xóa nhiệm vụ
  Future<bool> deleteTask(String taskId) async {
    try {
      await taskDataProvider.deleteTask(taskId);
      return true;
    } catch (e) {
      print('Lỗi khi xóa nhiệm vụ: $e');
      return false;
    }
  }
} 