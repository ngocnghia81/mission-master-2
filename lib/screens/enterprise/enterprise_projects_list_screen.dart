import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/models/enterprise_project_model.dart';
import 'package:mission_master/data/repositories/enterprise_project_repository.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnterpriseProjectsListScreen extends StatefulWidget {
  EnterpriseProjectsListScreen({Key? key}) : super(key: key);

  @override
  _EnterpriseProjectsListScreenState createState() => _EnterpriseProjectsListScreenState();
}

class _EnterpriseProjectsListScreenState extends State<EnterpriseProjectsListScreen> {
  late EnterpriseProjectRepository _repository;
  List<EnterpriseProject> _projects = [];
  List<EnterpriseProject> _filteredProjects = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    final prefs = await SharedPreferences.getInstance();
    _repository = EnterpriseProjectRepository(prefs);
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _repository.getAllProjects();
      setState(() {
        _projects = projects;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể tải danh sách dự án: $e');
    }
  }

  void _applyFilters() {
    _filteredProjects = _projects.where((project) {
      bool matchesStatus = _selectedStatus == 'all' || project.status == _selectedStatus;
      bool matchesType = _selectedType == 'all' || project.type == _selectedType;
      bool matchesSearch = _searchQuery.isEmpty ||
          project.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          project.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      return matchesStatus && matchesType && matchesSearch;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onStatusFilterChanged(String? status) {
    setState(() {
      _selectedStatus = status ?? 'all';
      _applyFilters();
    });
  }

  void _onTypeFilterChanged(String? type) {
    setState(() {
      _selectedType = type ?? 'all';
      _applyFilters();
    });
  }

  Future<void> _deleteProject(EnterpriseProject project) async {
    final confirmed = await _showDeleteConfirmDialog(project.name);
    if (!confirmed) return;

    try {
      await _repository.deleteProject(project.id);
      await _loadProjects();
      _showSuccessSnackBar('Dự án đã được xóa thành công');
    } catch (e) {
      _showErrorSnackBar('Không thể xóa dự án: $e');
    }
  }

  Future<bool> _showDeleteConfirmDialog(String projectName) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa dự án "$projectName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    ) ?? false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dự án Enterprise'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, AppRoutes.enterpriseProject);
          if (result == true) {
            await _loadProjects();
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildProjectStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildProjectsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm dự án...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    ...ProjectStatus.values.map((status) => 
                      DropdownMenuItem(value: status.value, child: Text(status.label))
                    ),
                  ],
                  onChanged: _onStatusFilterChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Loại dự án',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                    ...ProjectType.values.map((type) => 
                      DropdownMenuItem(value: type.value, child: Text(type.label))
                    ),
                  ],
                  onChanged: _onTypeFilterChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectStats() {
    final totalProjects = _projects.length;
    final activeProjects = _projects.where((p) => p.status == 'active').length;
    final overdueProjects = _projects.where((p) => p.isOverdue).length;
    final completedProjects = _projects.where((p) => p.status == 'completed').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Tổng', totalProjects, Colors.blue)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Đang thực hiện', activeProjects, Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Quá hạn', overdueProjects, Colors.red)),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard('Hoàn thành', completedProjects, Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsList() {
    if (_filteredProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _projects.isEmpty 
                  ? 'Chưa có dự án nào'
                  : 'Không tìm thấy dự án phù hợp',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProjects.length,
      itemBuilder: (context, index) {
        final project = _filteredProjects[index];
        return _buildProjectCard(project);
      },
    );
  }

  Widget _buildProjectCard(EnterpriseProject project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToProjectDetail(project),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(value, project),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Chỉnh sửa'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'tasks',
                        child: Row(
                          children: [
                            Icon(Icons.assignment, size: 18),
                            SizedBox(width: 8),
                            Text('Phân công nhiệm vụ'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'resources',
                        child: Row(
                          children: [
                            Icon(Icons.inventory, size: 18),
                            SizedBox(width: 8),
                            Text('Quản lý tài nguyên'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'budget',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Quản lý ngân sách'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'dashboard',
                        child: Row(
                          children: [
                            Icon(Icons.dashboard, size: 18),
                            SizedBox(width: 8),
                            Text('Dashboard'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Xóa', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  _buildStatusChip(project.status),
                  const SizedBox(width: 8),
                  _buildTypeChip(project.type),
                  if (project.isOverdue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Quá hạn',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(project.startDate)} - ${DateFormat('dd/MM/yyyy').format(project.endDate)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${project.memberEmails.length} thành viên',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              
              if (project.budget > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Ngân sách: ${NumberFormat.compact().format(project.budget)} VND',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Progress bar
              LinearProgressIndicator(
                value: project.progressPercentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  project.isOverdue ? Colors.red : AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tiến độ: ${project.progressPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'planning':
        color = Colors.orange;
        break;
      case 'active':
        color = Colors.green;
        break;
      case 'on_hold':
        color = Colors.yellow[700]!;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        ProjectStatus.values.firstWhere((s) => s.value == status).label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple),
      ),
      child: Text(
        ProjectType.values.firstWhere((t) => t.value == type).label,
        style: const TextStyle(
          color: Colors.purple,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _handleMenuAction(String action, EnterpriseProject project) {
    switch (action) {
      case 'edit':
        _navigateToEditProject(project);
        break;
      case 'tasks':
        _navigateToTaskAssignment(project);
        break;
      case 'resources':
        _navigateToResourceManagement(project);
        break;
      case 'budget':
        _navigateToBudgetManagement(project);
        break;
      case 'dashboard':
        _navigateToDashboard(project);
        break;
      case 'delete':
        _deleteProject(project);
        break;
    }
  }

  void _navigateToProjectDetail(EnterpriseProject project) {
    // Navigate to project detail screen
    // TODO: Implement project detail navigation
  }

  void _navigateToEditProject(EnterpriseProject project) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.enterpriseProject,
      arguments: project,
    );
    if (result == true) {
      await _loadProjects();
    }
  }

  void _navigateToTaskAssignment(EnterpriseProject project) {
    Navigator.pushNamed(
      context,
      AppRoutes.taskAssignment,
      arguments: {
        'projectId': project.id,
        'projectName': project.name,
      },
    );
  }

  void _navigateToResourceManagement(EnterpriseProject project) {
    Navigator.pushNamed(
      context,
      AppRoutes.resourceManagement,
      arguments: {
        'projectId': project.id,
      },
    );
  }

  void _navigateToBudgetManagement(EnterpriseProject project) {
    Navigator.pushNamed(
      context,
      AppRoutes.budgetManagement,
      arguments: {
        'projectId': project.id,
        'projectName': project.name,
      },
    );
  }

  void _navigateToDashboard(EnterpriseProject project) {
    Navigator.pushNamed(
      context,
      AppRoutes.enterpriseDashboard,
      arguments: project.id,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}