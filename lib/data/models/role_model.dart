import 'package:cloud_firestore/cloud_firestore.dart';

class UserRole {
  final String id;
  final String name;
  final String description;
  final List<String> permissions;
  final int accessLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserRole({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.accessLevel,
    this.createdAt,
    this.updatedAt,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      permissions: List<String>.from(json['permissions'] ?? []),
      accessLevel: json['accessLevel'] as int? ?? 0,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['createdAt']))
          : null,
      updatedAt: json['updatedAt'] != null 
          ? (json['updatedAt'] is Timestamp 
              ? (json['updatedAt'] as Timestamp).toDate() 
              : DateTime.fromMillisecondsSinceEpoch(json['updatedAt']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissions': permissions,
      'accessLevel': accessLevel,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  UserRole copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? permissions,
    int? accessLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserRole(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      accessLevel: accessLevel ?? this.accessLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Các quyền có sẵn trong hệ thống
class Permission {
  // Quyền dự án
  static const String viewProjects = 'view_projects';
  static const String createProject = 'create_project';
  static const String editProject = 'edit_project';
  static const String deleteProject = 'delete_project';
  
  // Quyền nhiệm vụ
  static const String viewTasks = 'view_tasks';
  static const String createTask = 'create_task';
  static const String editTask = 'edit_task';
  static const String deleteTask = 'delete_task';
  static const String assignTask = 'assign_task';
  
  // Quyền thành viên
  static const String viewMembers = 'view_members';
  static const String addMember = 'add_member';
  static const String removeMember = 'remove_member';
  static const String assignRole = 'assign_role';
  
  // Quyền báo cáo
  static const String viewReports = 'view_reports';
  static const String createReport = 'create_report';
  static const String exportReport = 'export_report';
  
  // Quyền tài nguyên và ngân sách
  static const String viewResources = 'view_resources';
  static const String manageResources = 'manage_resources';
  static const String viewBudget = 'view_budget';
  static const String manageBudget = 'manage_budget';
  
  // Quyền quản trị
  static const String manageRoles = 'manage_roles';
  static const String viewAuditLogs = 'view_audit_logs';
  static const String systemSettings = 'system_settings';
  
  // Danh sách tất cả các quyền
  static List<String> getAllPermissions() {
    return [
      viewProjects, createProject, editProject, deleteProject,
      viewTasks, createTask, editTask, deleteTask, assignTask,
      viewMembers, addMember, removeMember, assignRole,
      viewReports, createReport, exportReport,
      viewResources, manageResources, viewBudget, manageBudget,
      manageRoles, viewAuditLogs, systemSettings,
    ];
  }
  
  // Các vai trò mặc định
  static UserRole admin() {
    return UserRole(
      id: 'admin',
      name: 'Quản trị viên',
      description: 'Có tất cả các quyền trong hệ thống',
      permissions: getAllPermissions(),
      accessLevel: 100,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  static UserRole projectManager() {
    return UserRole(
      id: 'project_manager',
      name: 'Quản lý dự án',
      description: 'Quản lý dự án và thành viên',
      permissions: [
        viewProjects, createProject, editProject,
        viewTasks, createTask, editTask, deleteTask, assignTask,
        viewMembers, addMember, removeMember,
        viewReports, createReport, exportReport,
        viewResources, manageResources, viewBudget,
      ],
      accessLevel: 80,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  static UserRole teamMember() {
    return UserRole(
      id: 'team_member',
      name: 'Thành viên nhóm',
      description: 'Thành viên làm việc trong dự án',
      permissions: [
        viewProjects,
        viewTasks, createTask, editTask,
        viewMembers,
        viewReports,
        viewResources, viewBudget,
      ],
      accessLevel: 50,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  static UserRole viewer() {
    return UserRole(
      id: 'viewer',
      name: 'Người xem',
      description: 'Chỉ có quyền xem',
      permissions: [
        viewProjects,
        viewTasks,
        viewMembers,
        viewReports,
        viewResources, viewBudget,
      ],
      accessLevel: 10,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
} 