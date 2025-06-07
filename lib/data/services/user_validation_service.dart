import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';

class UserValidationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Kiểm tra email có tồn tại trong hệ thống hay không
  static Future<bool> isEmailRegistered(String email) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('User')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      
      return userQuery.docs.isNotEmpty;
    } catch (e) {
      print('Lỗi khi kiểm tra email: $e');
      return false;
    }
  }
  
  /// Lấy thông tin user từ email
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('User')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      
      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Lỗi khi lấy thông tin user: $e');
      return null;
    }
  }
  
  /// Kiểm tra user có trong project hay không (cho regular projects)
  static Future<bool> isUserInProject(String email, String projectId) async {
    try {
      final DocumentSnapshot projectDoc = await _firestore
          .collection('Project')
          .doc(projectId)
          .get();
      
      if (projectDoc.exists) {
        final data = projectDoc.data() as Map<String, dynamic>?;
        if (data != null && data['email'] != null) {
          final List<String> members = List<String>.from(data['email']);
          return members.contains(email.trim().toLowerCase());
        }
      }
      return false;
    } catch (e) {
      print('Lỗi khi kiểm tra thành viên trong dự án: $e');
      return false;
    }
  }
  
  /// Kiểm tra user có trong enterprise project hay không
  static Future<bool> isUserInEnterpriseProject(String email, String projectId) async {
    try {
      final DocumentSnapshot projectDoc = await _firestore
          .collection('EnterpriseProjects')
          .doc(projectId)
          .get();
      
      if (projectDoc.exists) {
        final data = projectDoc.data() as Map<String, dynamic>?;
        if (data != null && data['memberEmails'] != null) {
          final List<String> members = List<String>.from(data['memberEmails']);
          return members.contains(email.trim().toLowerCase());
        }
      }
      return false;
    } catch (e) {
      print('Lỗi khi kiểm tra thành viên trong dự án enterprise: $e');
      return false;
    }
  }
  
  /// Kiểm tra user có được giao task hay không
  static Future<bool> isUserAssignedToTask(String email, String taskId, String projectId) async {
    try {
      // Kiểm tra trong regular projects trước
      final QuerySnapshot regularTaskQuery = await _firestore
          .collection('Tasks')
          .doc(projectId)
          .collection('projectTasks')
          .where(FieldPath.documentId, isEqualTo: taskId)
          .limit(1)
          .get();
      
      if (regularTaskQuery.docs.isNotEmpty) {
        final taskData = regularTaskQuery.docs.first.data() as Map<String, dynamic>;
        if (taskData['Members'] != null) {
          final List<String> assignedMembers = List<String>.from(taskData['Members']);
          return assignedMembers.contains(email.trim().toLowerCase());
        }
      }
      
      // Kiểm tra trong enterprise projects nếu không tìm thấy ở regular
      final QuerySnapshot enterpriseTaskQuery = await _firestore
          .collection('EnterpriseTasks')
          .where('id', isEqualTo: taskId)
          .where('projectId', isEqualTo: projectId)
          .limit(1)
          .get();
      
      if (enterpriseTaskQuery.docs.isNotEmpty) {
        final taskData = enterpriseTaskQuery.docs.first.data() as Map<String, dynamic>;
        if (taskData['assignedTo'] != null) {
          final List<String> assignedMembers = List<String>.from(taskData['assignedTo']);
          return assignedMembers.contains(email.trim().toLowerCase());
        }
      }
      
      return false;
    } catch (e) {
      print('Lỗi khi kiểm tra user được giao task: $e');
      return false;
    }
  }
  
  /// Kiểm tra user có được giao task theo tên task (fallback method)
  static Future<bool> isUserAssignedToTaskByName(String email, String taskName) async {
    try {
      final String currentUserEmail = Auth.auth.currentUser?.email ?? '';
      if (currentUserEmail.isEmpty) return false;
      
      // Tìm trong tất cả các project tasks
      final QuerySnapshot tasksQuery = await _firestore
          .collectionGroup('projectTasks')
          .where('taskName', isEqualTo: taskName)
          .where('Members', arrayContains: email.trim().toLowerCase())
          .limit(1)
          .get();
      
      return tasksQuery.docs.isNotEmpty;
    } catch (e) {
      print('Lỗi khi kiểm tra user được giao task theo tên: $e');
      return false;
    }
  }
  
  /// Lấy danh sách email đã đăng ký trong hệ thống (cho autocomplete)
  static Future<List<String>> getRegisteredEmails({String? searchQuery}) async {
    try {
      Query query = _firestore.collection('User');
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Tìm kiếm email bắt đầu với query
        query = query
            .where('email', isGreaterThanOrEqualTo: searchQuery.toLowerCase())
            .where('email', isLessThan: searchQuery.toLowerCase() + 'z');
      }
      
      final QuerySnapshot usersSnapshot = await query.limit(20).get();
      
      return usersSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['email'] as String)
          .where((email) => email.isNotEmpty)
          .toList();
    } catch (e) {
      print('Lỗi khi lấy danh sách email: $e');
      return [];
    }
  }
  
  /// Validate multiple emails
  static Future<Map<String, bool>> validateMultipleEmails(List<String> emails) async {
    Map<String, bool> results = {};
    
    for (String email in emails) {
      if (email.trim().isEmpty) {
        results[email] = false;
        continue;
      }
      
      final bool isValid = await isEmailRegistered(email);
      results[email] = isValid;
    }
    
    return results;
  }
  
  /// Kiểm tra quyền truy cập chung
  static Future<bool> hasPermission(String action, {
    String? projectId,
    String? taskId,
    String? targetEmail,
  }) async {
    try {
      final String currentUserEmail = Auth.auth.currentUser?.email ?? '';
      if (currentUserEmail.isEmpty) return false;
      
      switch (action) {
        case 'ADD_MEMBER':
          // Chỉ project owner và admin mới được thêm thành viên
          if (projectId != null) {
            final projectDoc = await _firestore.collection('Project').doc(projectId).get();
            if (projectDoc.exists) {
              final data = projectDoc.data() as Map<String, dynamic>;
              return data['projectCreatedBy'] == currentUserEmail;
            }
          }
          return false;
          
        case 'ASSIGN_TASK':
          // Chỉ thành viên trong dự án mới được giao việc
          if (projectId != null) {
            return await isUserInProject(currentUserEmail, projectId) ||
                   await isUserInEnterpriseProject(currentUserEmail, projectId);
          }
          return false;
          
        case 'UPDATE_TASK_STATUS':
          // Chỉ người được giao mới được cập nhật trạng thái
          if (taskId != null && projectId != null) {
            return await isUserAssignedToTask(currentUserEmail, taskId, projectId);
          }
          return false;
          
        default:
          return false;
      }
    } catch (e) {
      print('Lỗi khi kiểm tra quyền: $e');
      return false;
    }
  }
} 