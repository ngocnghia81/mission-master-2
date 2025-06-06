import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/models/role_model.dart';
import 'package:mission_master/data/repositories/role_repository.dart';
import 'package:provider/provider.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({Key? key}) : super(key: key);

  @override
  _RoleManagementScreenState createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final RoleRepository _roleRepository = RoleRepository();
  List<UserRole> _roles = [];
  bool _isLoading = true;
  UserRole? _selectedRole;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Map<String, bool> _selectedPermissions = {};
  
  @override
  void initState() {
    super.initState();
    _loadRoles();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final roles = await _roleRepository.getAllRoles();
      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể tải danh sách vai trò: $e');
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _selectRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      _nameController.text = role.name;
      _descriptionController.text = role.description;
      
      // Reset permissions
      _selectedPermissions.clear();
      
      // Set selected permissions
      for (var permission in Permission.getAllPermissions()) {
        _selectedPermissions[permission] = role.permissions.contains(permission);
      }
    });
  }
  
  void _clearSelection() {
    setState(() {
      _selectedRole = null;
      _nameController.clear();
      _descriptionController.clear();
      _selectedPermissions.clear();
      
      // Initialize all permissions to false
      for (var permission in Permission.getAllPermissions()) {
        _selectedPermissions[permission] = false;
      }
    });
  }
  
  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;
    
    final List<String> permissions = _selectedPermissions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    if (permissions.isEmpty) {
      _showErrorSnackBar('Vui lòng chọn ít nhất một quyền');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_selectedRole == null) {
        // Tạo vai trò mới
        final newRole = UserRole(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          description: _descriptionController.text,
          permissions: permissions,
          accessLevel: 50, // Mức độ truy cập mặc định
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _roleRepository.createRole(newRole);
        _showSuccessSnackBar('Tạo vai trò mới thành công');
      } else {
        // Cập nhật vai trò hiện có
        final updatedRole = _selectedRole!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          permissions: permissions,
          updatedAt: DateTime.now(),
        );
        
        await _roleRepository.updateRole(updatedRole);
        _showSuccessSnackBar('Cập nhật vai trò thành công');
      }
      
      _clearSelection();
      await _loadRoles();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể lưu vai trò: $e');
    }
  }
  
  Future<void> _deleteRole(UserRole role) async {
    // Hiển thị hộp thoại xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa vai trò "${role.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _roleRepository.deleteRole(role.id);
      
      if (_selectedRole?.id == role.id) {
        _clearSelection();
      }
      
      await _loadRoles();
      _showSuccessSnackBar('Xóa vai trò thành công');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể xóa vai trò: $e');
    }
  }
  
  Widget _buildRoleList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_roles.isEmpty) {
      return const Center(
        child: Text('Chưa có vai trò nào được tạo'),
      );
    }
    
    return ListView.builder(
      itemCount: _roles.length,
      itemBuilder: (context, index) {
        final role = _roles[index];
        final isSelected = _selectedRole?.id == role.id;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isSelected ? AppColors.primaryLight : null,
          child: ListTile(
            title: Text(
              role.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              '${role.description} • ${role.permissions.length} quyền',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRole(role),
            ),
            onTap: () => _selectRole(role),
          ),
        );
      },
    );
  }
  
  Widget _buildPermissionGroup(String title, List<String> permissions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 0.0,
          children: permissions.map((permission) {
            return FilterChip(
              label: Text(_getPermissionLabel(permission)),
              selected: _selectedPermissions[permission] ?? false,
              onSelected: (selected) {
                setState(() {
                  _selectedPermissions[permission] = selected;
                });
              },
              selectedColor: AppColors.primaryLight,
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }
  
  String _getPermissionLabel(String permission) {
    // Chuyển đổi chuỗi 'view_projects' thành 'Xem dự án'
    final parts = permission.split('_');
    if (parts.length < 2) return permission;
    
    String action = parts[0];
    String resource = parts.sublist(1).join(' ');
    
    switch (action) {
      case 'view': action = 'Xem'; break;
      case 'create': action = 'Tạo'; break;
      case 'edit': action = 'Sửa'; break;
      case 'delete': action = 'Xóa'; break;
      case 'manage': action = 'Quản lý'; break;
      case 'assign': action = 'Gán'; break;
      case 'add': action = 'Thêm'; break;
      case 'remove': action = 'Xóa'; break;
      case 'export': action = 'Xuất'; break;
    }
    
    return '$action $resource';
  }
  
  Widget _buildRoleForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedRole == null ? 'Tạo vai trò mới' : 'Chỉnh sửa vai trò',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Tên vai trò',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập tên vai trò';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mô tả vai trò';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Quyền hạn',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Nhóm quyền dự án
          _buildPermissionGroup('Dự án', [
            Permission.viewProjects,
            Permission.createProject,
            Permission.editProject,
            Permission.deleteProject,
          ]),
          
          // Nhóm quyền nhiệm vụ
          _buildPermissionGroup('Nhiệm vụ', [
            Permission.viewTasks,
            Permission.createTask,
            Permission.editTask,
            Permission.deleteTask,
            Permission.assignTask,
          ]),
          
          // Nhóm quyền thành viên
          _buildPermissionGroup('Thành viên', [
            Permission.viewMembers,
            Permission.addMember,
            Permission.removeMember,
            Permission.assignRole,
          ]),
          
          // Nhóm quyền báo cáo
          _buildPermissionGroup('Báo cáo', [
            Permission.viewReports,
            Permission.createReport,
            Permission.exportReport,
          ]),
          
          // Nhóm quyền tài nguyên và ngân sách
          _buildPermissionGroup('Tài nguyên & Ngân sách', [
            Permission.viewResources,
            Permission.manageResources,
            Permission.viewBudget,
            Permission.manageBudget,
          ]),
          
          // Nhóm quyền quản trị
          _buildPermissionGroup('Quản trị', [
            Permission.manageRoles,
            Permission.viewAuditLogs,
            Permission.systemSettings,
          ]),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _clearSelection,
                child: const Text('Hủy'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _saveRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(_selectedRole == null ? 'Tạo vai trò' : 'Cập nhật'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý vai trò'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _clearSelection,
            tooltip: 'Tạo vai trò mới',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoles,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading && _roles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Danh sách vai trò (chiếm 1/3 màn hình)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Danh sách vai trò (${_roles.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: _buildRoleList()),
                    ],
                  ),
                ),
                // Đường ngăn cách
                const VerticalDivider(width: 1),
                // Form chỉnh sửa vai trò (chiếm 2/3 màn hình)
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildRoleForm(),
                  ),
                ),
              ],
            ),
    );
  }
} 