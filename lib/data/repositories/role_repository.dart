import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/models/role_model.dart';

class RoleRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'roles';

  RoleRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Lấy tất cả vai trò
  Future<List<UserRole>> getAllRoles() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs
          .map((doc) => UserRole.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting roles: $e');
      return [];
    }
  }

  // Lấy vai trò theo ID
  Future<UserRole?> getRoleById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return UserRole.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Error getting role by ID: $e');
      return null;
    }
  }

  // Tạo vai trò mới
  Future<String?> createRole(UserRole role) async {
    try {
      final docRef = await _firestore.collection(_collection).add({
        ...role.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating role: $e');
      return null;
    }
  }

  // Cập nhật vai trò
  Future<bool> updateRole(UserRole role) async {
    try {
      await _firestore.collection(_collection).doc(role.id).update({
        ...role.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating role: $e');
      return false;
    }
  }

  // Xóa vai trò
  Future<bool> deleteRole(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting role: $e');
      return false;
    }
  }

  // Kiểm tra xem người dùng có quyền cụ thể không
  Future<bool> userHasPermission(String userId, String permission) async {
    try {
      // Lấy vai trò của người dùng từ collection users
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data();
      if (userData == null || !userData.containsKey('roleId')) return false;

      final roleId = userData['roleId'];
      final roleDoc = await _firestore.collection(_collection).doc(roleId).get();
      if (!roleDoc.exists) return false;

      final roleData = roleDoc.data();
      if (roleData == null || !roleData.containsKey('permissions')) return false;

      final permissions = List<String>.from(roleData['permissions']);
      return permissions.contains(permission);
    } catch (e) {
      print('Error checking user permission: $e');
      return false;
    }
  }

  // Gán vai trò cho người dùng
  Future<bool> assignRoleToUser(String userId, String roleId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'roleId': roleId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error assigning role to user: $e');
      return false;
    }
  }

  // Khởi tạo các vai trò mặc định
  Future<void> initDefaultRoles() async {
    try {
      // Kiểm tra xem đã có vai trò nào chưa
      final snapshot = await _firestore.collection(_collection).limit(1).get();
      if (snapshot.docs.isNotEmpty) return; // Đã có vai trò, không cần khởi tạo

      // Tạo các vai trò mặc định
      final adminRole = Permission.admin();
      final pmRole = Permission.projectManager();
      final memberRole = Permission.teamMember();
      final viewerRole = Permission.viewer();

      // Lưu vào Firestore
      await _firestore.collection(_collection).doc(adminRole.id).set({
        ...adminRole.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection(_collection).doc(pmRole.id).set({
        ...pmRole.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection(_collection).doc(memberRole.id).set({
        ...memberRole.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection(_collection).doc(viewerRole.id).set({
        ...viewerRole.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error initializing default roles: $e');
    }
  }
} 