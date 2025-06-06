import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/notification/notification_services.dart';

class Database {
  final projectController = Get.put(ProjectController());
  NotificationServices noti = NotificationServices();
  Database() {
    print('sda');
  }
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
  int _projectId = 0;
  int generateProjectNo() {
    _projectId = Random().nextInt(560000);
    return _projectId;
  }

  Future<bool> addWorkspace({
    required String projectName,
    required String projectDescription,
    required List<String> email,
    required String creationDate,
  }) async {
    int projectId = generateProjectNo();

    await firestore.collection('Project').doc(projectId.toString()).set({
      "projectId": projectId,
      "projectName": projectName,
      "projectDescription": projectDescription,
      "email": email,
      "projectCreatedBy": Auth.auth.currentUser!.email,
      "createdOn": creationDate,
    }, SetOptions(merge: true));

    return true;
  }

  Stream<QuerySnapshot> getCreatedProjects() {
    return firestore
        .collection('Project')
        .where('projectCreatedBy', isEqualTo: Auth.auth.currentUser!.email)
        .snapshots();
  }

  Future<bool> addTaskToProject({
    required String task,
    required String description,
    required String date,
    required String time,
    required List<String> members,
    String priority = 'normal',
    bool isRecurring = false,
    String recurringInterval = '',
  }) async {
    // Create task in the project collection
    await firestore
        .collection('Tasks')
        .doc(projectController.projectId.string)
        .set({'projectId': projectController.projectId.string});

    // Add task details
    await firestore
        .collection('Tasks')
        .doc(projectController.projectId.string)
        .collection('projectTasks')
        .doc()
        .set({
          'taskName': task,
          'description': description,
          'deadlineDate': date,
          'deadlineTime': time,
          'Members': members,
          'projectName': projectController.projectName.string,
          'status': 'Chưa bắt đầu',
          'priority': priority,
          'isRecurring': isRecurring,
          'recurringInterval': recurringInterval,
        }, SetOptions(merge: true));
    
    // Gửi thông báo đến tất cả thành viên được giao việc
    await noti.sendTaskAssignmentNotification(
      taskName: task,
      projectName: projectController.projectName.string,
      deadline: "$date $time",
      members: members,
    );

    return true;
  }

  Stream<QuerySnapshot> getAllProjects() {
    return firestore
        .collection('Project')
        .where(
          Filter.or(
            Filter("email", arrayContains: Auth.auth!.currentUser!.email),
            Filter(
              'projectCreatedBy',
              isEqualTo: Auth.auth!.currentUser!.email,
            ),
          ),
        )
        .snapshots();
  }

  Stream<QuerySnapshot> getTasksAsPerStatus({required String taskStatus}) {
    String currentUserEmail =
        FirebaseAuth.instance.currentUser!.email.toString();
    print(taskStatus);
    return firestore
        .collectionGroup('projectTasks')
        .where('Members', arrayContains: currentUserEmail)
        .where('status', isEqualTo: taskStatus)
        .snapshots();
  }

  Future<bool> updateTaskStatus({
    required String taskName,
    required String changeStatusTo,
    String? taskId,
    String? projectId,
  }) async {
    try {
      // Kiểm tra xem người dùng hiện tại có quyền cập nhật trạng thái không
      final currentUserEmail = Auth.auth.currentUser?.email;
      if (currentUserEmail == null) {
        print("Lỗi: Người dùng chưa đăng nhập");
        return false;
      }
      
      QuerySnapshot snap;
      String? projectName;
      String? currentStatus;
      
      if (taskId != null && projectId != null) {
        print("Đang cập nhật task với ID: $taskId trong dự án: $projectId");
        
        // Kiểm tra xem taskId và projectId có giống nhau không
        if (taskId == projectId) {
          print("Lỗi: Task ID và Project ID giống nhau, cố gắng tìm task theo tên");
          
          // Thử tìm task trong tất cả các project
          final projectsSnap = await firestore.collection('Tasks').get();
          
          for (var projectDoc in projectsSnap.docs) {
            final projectTasksSnap = await projectDoc.reference
                .collection('projectTasks')
                .where('taskName', isEqualTo: taskName)
                .where('Members', arrayContains: currentUserEmail)
                .get();
                
            if (projectTasksSnap.docs.isNotEmpty) {
              // Tìm thấy task, cập nhật trạng thái
              final taskDoc = projectTasksSnap.docs.first;
              final taskData = taskDoc.data();
              currentStatus = taskData['status'] as String?;
              
              // Kiểm tra quyền cập nhật
              final List<String> members = List<String>.from(taskData['Members'] ?? []);
              if (!members.contains(currentUserEmail)) {
                print("Lỗi: Người dùng $currentUserEmail không có quyền cập nhật task này");
                return false;
              }
              
              await taskDoc.reference.update({
                'status': changeStatusTo,
                'lastUpdatedBy': currentUserEmail,
                'lastUpdatedAt': DateTime.now(),
              });
              
              print("Đã cập nhật task '${taskName}' trong project ${projectDoc.id}");
              return true;
            }
          }
          
          print("Không tìm thấy task với tên: $taskName");
          return false;
        }
        
        // Kiểm tra xem tài liệu có tồn tại không trước khi cập nhật
        final taskDocRef = firestore
            .collection('Tasks')
            .doc(projectId)
            .collection('projectTasks')
            .doc(taskId);
            
        final taskDoc = await taskDocRef.get();
        if (!taskDoc.exists) {
          print("Lỗi: Không tìm thấy task với ID: $taskId trong dự án: $projectId");
          return false;
        }
            
        // Lấy thông tin dự án và trạng thái hiện tại
        final projectDoc = await firestore.collection('Project').doc(projectId).get();
        if (projectDoc.exists) {
          final projectData = projectDoc.data() as Map<String, dynamic>;
          projectName = projectData['projectName'] as String?;
        }
        
        // Lấy trạng thái hiện tại của task từ tài liệu đã kiểm tra
          final taskData = taskDoc.data() as Map<String, dynamic>;
          currentStatus = taskData['status'] as String?;
        
        // Kiểm tra quyền cập nhật
        final List<String> members = List<String>.from(taskData['Members'] ?? []);
        if (!members.contains(currentUserEmail)) {
          print("Lỗi: Người dùng $currentUserEmail không có quyền cập nhật task này");
          return false;
        }
        
        // Cập nhật task với ID và project ID đã biết
        await taskDocRef.update({
              'status': changeStatusTo,
          'lastUpdatedBy': currentUserEmail,
              'lastUpdatedAt': DateTime.now(),
            });
            
        // Lưu lịch sử cập nhật
        if (currentStatus != null && currentStatus != changeStatusTo) {
          await taskDocRef
              .collection('statusUpdates')
              .add({
                'fromStatus': currentStatus,
                'toStatus': changeStatusTo,
                'updatedBy': Auth.auth.currentUser!.displayName ?? currentUserEmail,
                'timestamp': FieldValue.serverTimestamp(),
              });
        }
      } else {
        // Thay vì dùng collectionGroup, tìm task trong tất cả các project
        print("Tìm task với tên: $taskName cho người dùng: $currentUserEmail");
        
        // Lấy tất cả các project
        final projectsSnap = await firestore.collection('Tasks').get();
        bool foundTask = false;
        
        // Duyệt qua từng project để tìm task
        for (var projectDoc in projectsSnap.docs) {
          final projectTasksSnap = await projectDoc.reference
              .collection('projectTasks')
            .where('taskName', isEqualTo: taskName)
              .where('Members', arrayContains: currentUserEmail)
            .get();
            
          if (projectTasksSnap.docs.isNotEmpty) {
            // Tìm thấy task, lấy thông tin
            final taskDoc = projectTasksSnap.docs.first;
            final taskData = taskDoc.data();
        projectName = taskData['projectName'] as String?;
        currentStatus = taskData['status'] as String?;
        
            // Kiểm tra quyền cập nhật
            final List<String> members = List<String>.from(taskData['Members'] ?? []);
            if (!members.contains(currentUserEmail)) {
              print("Lỗi: Người dùng $currentUserEmail không có quyền cập nhật task này");
              continue; // Tiếp tục tìm task khác nếu có
            }
            
            // Cập nhật task
            await taskDoc.reference.update({
          'status': changeStatusTo,
              'lastUpdatedBy': currentUserEmail,
          'lastUpdatedAt': DateTime.now(),
        });
        
        // Lưu lịch sử cập nhật
            if (currentStatus != null && currentStatus != changeStatusTo) {
              await taskDoc.reference
              .collection('statusUpdates')
              .add({
                'fromStatus': currentStatus,
                'toStatus': changeStatusTo,
                    'updatedBy': Auth.auth.currentUser!.displayName ?? currentUserEmail,
                'timestamp': FieldValue.serverTimestamp(),
              });
        }
        
        // Nếu task được đánh dấu là hoàn thành, kiểm tra xem có trễ hạn không
        if (changeStatusTo.toLowerCase() == 'completed') {
          final String deadlineDate = taskData['deadlineDate'] as String;
          
          try {
            // Chuyển đổi deadline thành DateTime
            final dateFormat = deadlineDate.split('/');
            if (dateFormat.length == 3) {
              final deadline = DateTime(
                int.parse(dateFormat[2]), 
                int.parse(dateFormat[1]), 
                int.parse(dateFormat[0])
              );
              
              // Nếu đã quá hạn, thông báo cho người dùng
              if (DateTime.now().isAfter(deadline)) {
                // Gửi thông báo hoàn thành trễ
                noti.showLocalNotification(
                  title: 'Công việc hoàn thành trễ hạn',
                  body: 'Công việc "$taskName" trong dự án "${projectName ?? ''}" đã được hoàn thành sau hạn chót',
                );
                
                // Thông báo cho các thành viên khác
                _notifyOtherMembers(
                  taskData: taskData,
                  title: 'Công việc đã hoàn thành trễ hạn',
                  body: '${Auth.auth.currentUser!.displayName} đã hoàn thành công việc "$taskName" trong dự án "${projectName ?? ''}" (trễ hạn)',
                );
              } else {
                // Gửi thông báo hoàn thành đúng hạn
                noti.showLocalNotification(
                  title: 'Công việc hoàn thành',
                  body: 'Công việc "$taskName" trong dự án "${projectName ?? ''}" đã được hoàn thành đúng hạn',
                );
                
                // Thông báo cho các thành viên khác
                _notifyOtherMembers(
                  taskData: taskData,
                  title: 'Công việc đã hoàn thành',
                  body: '${Auth.auth.currentUser!.displayName} đã hoàn thành công việc "$taskName" trong dự án "${projectName ?? ''}"',
                );
              }
            }
          } catch (e) {
            print('Lỗi khi kiểm tra deadline: $e');
          }
        } else if (changeStatusTo.toLowerCase() == 'in progress') {
          // Thông báo task đang được thực hiện
          noti.showLocalNotification(
            title: 'Công việc đang thực hiện',
            body: 'Công việc "$taskName" trong dự án "${projectName ?? ''}" đã được bắt đầu thực hiện',
          );
          
          // Thông báo cho các thành viên khác
          _notifyOtherMembers(
            taskData: taskData,
            title: 'Công việc đã được bắt đầu',
            body: '${Auth.auth.currentUser!.displayName} đã bắt đầu thực hiện công việc "$taskName" trong dự án "${projectName ?? ''}"',
          );
            }
            
            foundTask = true;
            break;
          }
        }
        
        if (!foundTask) {
          print("Không tìm thấy task với tên: $taskName hoặc người dùng không có quyền cập nhật");
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('Lỗi cập nhật trạng thái: $e');
      return false;
    }
  }
  
  // Gửi thông báo cho các thành viên khác trong task
  void _notifyOtherMembers({
    required Map<String, dynamic> taskData,
    required String title,
    required String body,
  }) async {
    try {
      // Lấy danh sách email của các thành viên
      final List<String> members = List<String>.from(taskData['Members'] ?? []);
      
      // Lọc ra các thành viên khác (không phải người dùng hiện tại)
      final currentUserEmail = Auth.auth.currentUser?.email;
      final otherMembers = members.where((email) => email != currentUserEmail).toList();
      
      // Lưu thông báo cho từng thành viên
      DateTime today = DateTime.now();
      String currentDate = "${today.day}/${today.month}/${today.year}";
      
      for (String member in otherMembers) {
        // Lưu thông báo vào Firestore
        await firestore.collection('Notifications').doc().set({
          'title': title,
          'body': body,
          'receiveDate': currentDate,
          'receiveTo': member,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Lỗi khi gửi thông báo: $e');
    }
  }

  Future<double?> getProgress({required String id}) async {
    try {
      print("Đang tính tiến độ cho dự án: $id");
      
      // Lấy tổng số task
      AggregateQuerySnapshot allDocs =
          await firestore
              .collection('Tasks')
              .doc(id.toString())
              .collection('projectTasks')
              .count()
              .get();
              
      // Lấy số task đã hoàn thành - kiểm tra tất cả các trạng thái có thể
      List<String> completedStatuses = ['completed', 'Completed', 'hoàn thành', 'Hoàn thành', 'hoàn tất', 'Hoàn tất'];
      int totalCompleted = 0;
      
      // Đếm tổng số task hoàn thành với tất cả các trạng thái có thể
      for (String status in completedStatuses) {
        AggregateQuerySnapshot completedSnapshot =
            await firestore
                .collection('Tasks')
                .doc(id)
                .collection('projectTasks')
                .where('status', isEqualTo: status)
                .count()
                .get();
        
        totalCompleted += completedSnapshot.count!;
        print("Số task hoàn thành với trạng thái '$status': ${completedSnapshot.count}");
      }
              
      print("Tổng số task: ${allDocs.count}");
      print("Tổng số task hoàn thành: $totalCompleted");
      
      if (allDocs.count == 0) return 0.0;
      double percentage = totalCompleted / allDocs.count!.toInt();
      print("Tỷ lệ hoàn thành: ${percentage * 100}%");
      return percentage;
    } catch (e) {
      print("Lỗi khi tính tiến độ: $e");
      return 0.0;
    }
  }

  Future<bool> removeMemberToProject({required String email}) async {
    await firestore
        .collection('Project')
        .doc(projectController.projectId.string)
        .update({
          'email': FieldValue.arrayRemove([email]),
        });

    return true;
  }

  Future<bool> addMemberToProject({required String email}) async {
    await firestore
        .collection('Project')
        .doc(projectController.projectId.string)
        .update({
          'email': FieldValue.arrayUnion([email]),
        });

    return true;
  }

  Stream<DocumentSnapshot> getMembersOfProject() {
    return firestore
        .collection('Project')
        .doc(projectController.projectId.string)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserDetail() {
    return firestore
        .collection('User')
        .where('email', isEqualTo: projectController.projectCreatedBy.value)
        .snapshots();
  }

  Future<void> sendDeadlineReminder() async {
    try {
      DateTime today = DateTime.now();
      String formattedDate = "${today.day}/${today.month}/${today.year}";

      // First query to get tasks with today's deadline
      QuerySnapshot deadlineTasks = await firestore
          .collectionGroup('projectTasks')
          .where('Members', arrayContains: Auth.auth.currentUser!.email)
          .where('deadlineDate', isEqualTo: formattedDate)
          .get();

      // Then filter locally for tasks that are not completed
      List<DocumentSnapshot> incompleteTasks = deadlineTasks.docs
          .where((doc) => doc['status'].toString().toLowerCase() != 'completed')
          .toList();

      if (incompleteTasks.isNotEmpty) {
        print("length:${incompleteTasks.length}");
        for (int i = 0; i < incompleteTasks.length; i++) {
          DocumentSnapshot doc = incompleteTasks[i];
          print(doc['projectName']);
          noti.sendFCM(projectName: doc['projectName']);
        }
      }
    } catch (e) {
      print("Error sending deadline reminder: $e");
    }
  }

  Future<void> saveNotifications({
    required String title,
    required String body,
  }) async {
    DateTime today = DateTime.now();
    await firestore.collection('Notifications').doc().set({
      'title': title,
      'body': body,
      'receiveDate': "${today.day}/${today.month}/${today.year}",
      'receiveTo': Auth.auth.currentUser!.email, // Sử dụng email thay vì uid
      'isRead': false, // Thêm trường isRead mặc định là false
      'timestamp': FieldValue.serverTimestamp(), // Thêm timestamp để sắp xếp chính xác hơn
    });
  }

  Future<bool> addComments({
    required String id,
    required String comment,
  }) async {
    FirebaseFirestore.instance.collection('Comments').doc(id).set({
      'taskId': id,
    });
    FirebaseFirestore.instance
        .collection('Comments')
        .doc(id)
        .collection('taskComments')
        .doc()
        .set({
          'comment': comment,
          'author': Auth.auth.currentUser!.displayName,
          'time': DateTime.now(),
        });

    return true;
  }

  Stream<QuerySnapshot> getComments({required String id}) {
    return FirebaseFirestore.instance
        .collection('Comments')
        .doc(id)
        .collection('taskComments')
        .orderBy('time', descending: true)
        .snapshots();
  }

  // Chuyển đổi tất cả thông báo cũ sang định dạng mới
  Future<void> migrateNotifications() async {
    try {
      // Lấy thông tin người dùng hiện tại
      User? currentUser = Auth.auth.currentUser;
      if (currentUser == null) return;

      // Lấy danh sách tất cả thông báo của người dùng theo uid
      QuerySnapshot notificationsSnapshot = await firestore
          .collection('Notifications')
          .where('receiveTo', isEqualTo: currentUser.uid)
          .get();

      // Cập nhật từng thông báo để sử dụng email thay vì uid
      for (DocumentSnapshot doc in notificationsSnapshot.docs) {
        await doc.reference.update({
          'receiveTo': currentUser.email,
        });
      }

      print("Đã chuyển đổi ${notificationsSnapshot.docs.length} thông báo sang định dạng mới");
    } catch (e) {
      print("Lỗi khi chuyển đổi thông báo: $e");
    }
  }
}
