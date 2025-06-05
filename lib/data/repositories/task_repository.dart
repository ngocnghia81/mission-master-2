import 'dart:async';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';

class TaskRepository {
  final TaskDataProvider taskDataProvider;
  final _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TaskRepository({required this.taskDataProvider});

  Future<List<Task>> getTasks() async {
    try {
      // Lấy dữ liệu từ SharedPreferences
      final localTasks = await taskDataProvider.getTasks();
      print('Lấy ${localTasks.length} task từ bộ nhớ cục bộ');
      
      // Nếu có dữ liệu trong bộ nhớ cục bộ, trả về luôn
      if (localTasks.isNotEmpty) {
        print('Trả về ${localTasks.length} task từ bộ nhớ cục bộ');
        return localTasks;
      }
      
      // Nếu không có dữ liệu trong bộ nhớ cục bộ, đồng bộ từ Firebase
      print('Không có dữ liệu trong bộ nhớ cục bộ, đồng bộ từ Firebase');
      await syncTasksFromFirebase();
      
      // Lấy lại dữ liệu từ SharedPreferences sau khi đồng bộ
      final syncedTasks = await taskDataProvider.getTasks();
      print('Sau khi đồng bộ, có ${syncedTasks.length} task');
      
      return syncedTasks;
    } catch (e) {
      print('Error fetching tasks: $e');
      // Nếu có lỗi, trả về dữ liệu local
      return await taskDataProvider.getTasks();
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
      tasks[index] = tasks[index].copyWith(status: status);
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
      
      // Lấy tất cả các project mà người dùng tham gia
      final QuerySnapshot projectsSnapshot = await _firestore
          .collection('Project')
          .where(Filter.or(
            Filter("email", arrayContains: currentUserEmail),
            Filter("projectCreatedBy", isEqualTo: currentUserEmail)
          ))
          .get();
          
      print('Tìm thấy ${projectsSnapshot.docs.length} dự án');
      
      final List<Task> firebaseTasks = [];
      
      // Duyệt qua từng project để lấy tasks
      for (var projectDoc in projectsSnapshot.docs) {
        final String projectId = projectDoc.id;
        final projectData = projectDoc.data() as Map<String, dynamic>;
        final String projectName = projectData['projectName'] as String? ?? 'Dự án không tên';
        
        print('Đang lấy task từ dự án: $projectName (ID: $projectId)');
        
        // Lấy tất cả các task trong project
        final QuerySnapshot taskSnapshot = await _firestore
            .collection('Tasks')
            .doc(projectId)
            .collection('projectTasks')
            .get();
            
        print('Tìm thấy ${taskSnapshot.docs.length} task trong dự án $projectName');
        
        for (var doc in taskSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          // In thông tin chi tiết về task
          print('Task ID: ${doc.id}');
          print('Task Name: ${data['taskName']}');
          print('Deadline: ${data['deadlineDate']} ${data['deadlineTime']}');
          print('Members: ${data['Members']}');
          print('Status: ${data['status']}');
          
          // Lọc các task có chứa email người dùng trong danh sách members trên phía client
          final List<String> members = List<String>.from(data['Members'] ?? []);
          
          // Thêm task vào danh sách bất kể có phải là thành viên hay không để đảm bảo hiển thị đầy đủ
          final task = _convertToTask(doc.id, data);
          firebaseTasks.add(task);
          
          if (members.contains(currentUserEmail)) {
            print('✓ Task được gán cho người dùng $currentUserEmail: ${task.title}');
          } else {
            print('✗ Task không được gán cho người dùng $currentUserEmail: ${task.title}');
          }
        }
      }
      
      // Lấy tasks hiện có từ SharedPreferences
      final localTasks = await taskDataProvider.getTasks();
      print('Số task trong bộ nhớ cục bộ: ${localTasks.length}');
      
      // Kết hợp dữ liệu từ cả hai nguồn, loại bỏ trùng lặp
      final Map<String, Task> uniqueTasks = {};
      
      // Thêm tasks từ SharedPreferences
      for (var task in localTasks) {
        uniqueTasks[task.id] = task;
      }
      
      // Thêm tasks từ Firebase
      for (var task in firebaseTasks) {
        uniqueTasks[task.id] = task;
      }
      
      // Lưu lại dữ liệu kết hợp vào SharedPreferences
      final allTasks = uniqueTasks.values.toList();
      await taskDataProvider.saveTasks(allTasks);
      
      print('Đồng bộ hoàn tất: ${firebaseTasks.length} task từ Firebase, tổng cộng ${allTasks.length} task');
      
      // In ra tất cả các ngày có trong dữ liệu để debug
      final allDates = allTasks.map((task) => task.deadlineDate).toSet().toList();
      print('Các ngày có trong dữ liệu sau khi đồng bộ: $allDates');
    } catch (e) {
      print('Error syncing tasks from Firebase: $e');
    }
  }

  // Xóa dữ liệu cục bộ và buộc đồng bộ lại từ Firebase
  Future<void> clearLocalTasks() async {
    try {
      // Xóa dữ liệu cục bộ
      await taskDataProvider.saveTasks([]);
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
} 