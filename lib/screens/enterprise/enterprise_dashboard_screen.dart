import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/models/resource_model.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:mission_master/data/repositories/resource_repository.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnterpriseDashboardScreen extends StatefulWidget {
  final String projectId;
  
  const EnterpriseDashboardScreen({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  _EnterpriseDashboardScreenState createState() => _EnterpriseDashboardScreenState();
}

class _EnterpriseDashboardScreenState extends State<EnterpriseDashboardScreen> {
  late final TaskRepository _taskRepository;
  final ResourceRepository _resourceRepository = ResourceRepository();
  
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  List<Resource> _resources = [];
  Budget? _budget;
  bool _isLoading = true;
  bool _showMyTasksOnly = false;
  String _selectedTaskFilter = 'all';
  
  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }
  
  Future<void> _initializeAndLoadData() async {
    final prefs = await SharedPreferences.getInstance();
    _taskRepository = TaskRepository(
      taskDataProvider: TaskDataProvider(prefs),
    );
    await _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Lấy nhiệm vụ trực tiếp từ Firebase thay vì từ bộ nhớ cục bộ
      final tasks = await _taskRepository.getEnterpriseTasksFromFirebase(
        projectId: widget.projectId,
        onlyCurrentUser: _showMyTasksOnly,
        statusFilter: _selectedTaskFilter,
      );
      
      final resources = await _resourceRepository.getProjectResources(widget.projectId);
      
      // Đồng bộ ngân sách trước khi lấy dữ liệu
      await _resourceRepository.syncBudgetWithItems(widget.projectId);
      final budget = await _resourceRepository.getProjectBudget(widget.projectId);
      
      setState(() {
        _tasks = tasks;
        _filteredTasks = tasks; // Không cần lọc lại vì đã được lọc từ Firebase
        _resources = resources;
        _budget = budget;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tải dữ liệu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Thay đổi bộ lọc nhiệm vụ
  void _toggleMyTasksFilter() {
    final currentUserEmail = Auth.auth.currentUser?.email;
    print('Chuyển đổi bộ lọc nhiệm vụ của tôi: ${!_showMyTasksOnly}');
    print('Email người dùng hiện tại: $currentUserEmail');
    
    setState(() {
      _showMyTasksOnly = !_showMyTasksOnly;
      _loadData(); // Tải lại dữ liệu từ Firebase với bộ lọc mới
    });
  }
  
  // Thay đổi bộ lọc trạng thái
  void _changeStatusFilter(String status) {
    setState(() {
      _selectedTaskFilter = status;
      _loadData(); // Tải lại dữ liệu từ Firebase với bộ lọc mới
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUserEmail = Auth.auth.currentUser?.email;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debug info
                  Card(
                    color: Colors.amber[100],
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email người dùng: $currentUserEmail', 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Tổng số nhiệm vụ: ${_tasks.length}'),
                          Text('Nhiệm vụ đã lọc: ${_filteredTasks.length}'),
                          Text('Lọc nhiệm vụ của tôi: $_showMyTasksOnly'),
                          Text('Lọc trạng thái: $_selectedTaskFilter'),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: _createTestTask,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                child: const Text('Tạo nhiệm vụ kiểm tra', style: TextStyle(color: Colors.white)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  for (var task in _tasks) {
                                    print('Task: ${task.title}');
                                    print('Members: ${task.members}');
                                    print('User in members: ${task.members.contains(currentUserEmail)}');
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Debug tasks', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('Danh sách email trong các nhiệm vụ:', 
                            style: TextStyle(fontWeight: FontWeight.bold)),
                          ..._tasks.map((task) => Text('${task.title}: ${task.members.join(", ")}')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tổng quan
                  _buildOverviewSection(),
                  const SizedBox(height: 24),
                  
                  // Bộ lọc nhiệm vụ
                  _buildTaskFilters(),
                  const SizedBox(height: 16),
                  
                  // Danh sách nhiệm vụ
                  _buildTasksList(),
                  const SizedBox(height: 24),
                  
                  // Biểu đồ trạng thái nhiệm vụ
                  _buildTaskStatusChart(),
                  const SizedBox(height: 24),
                  
                  // Tài nguyên và ngân sách
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: _buildResourceOverview()),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: _buildBudgetOverview()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Các tính năng Enterprise
                  _buildEnterpriseFeatures(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildOverviewSection() {
    int totalTasks = _filteredTasks.length;
    int completedTasks = _filteredTasks.where((task) => task.status == 'completed').length;
    int activeTasks = _filteredTasks.where((task) => task.status == 'in_progress').length;
    double totalResourceCost = _resources.fold(0.0, (sum, resource) => sum + resource.getTotalCost());
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng quan dự án',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Tổng nhiệm vụ',
                    totalTasks.toString(),
                    Icons.assignment,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Hoàn thành',
                    completedTasks.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Đang thực hiện',
                    activeTasks.toString(),
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Chi phí tài nguyên',
                    NumberFormat.compact().format(totalResourceCost),
                    Icons.monetization_on,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskStatusChart() {
    if (_filteredTasks.isEmpty) {
      return const SizedBox.shrink();
    }
    
    int completedTasks = _filteredTasks.where((task) => task.status == 'completed').length;
    int inProgressTasks = _filteredTasks.where((task) => task.status == 'in_progress').length;
    int pendingTasks = _filteredTasks.where((task) => task.status == 'pending').length;
    int totalTasks = _filteredTasks.length;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phân bố trạng thái nhiệm vụ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(enabled: false),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (completedTasks > 0)
                            PieChartSectionData(
                              color: Colors.green,
                              value: completedTasks.toDouble(),
                              title: '${((completedTasks / totalTasks) * 100).toStringAsFixed(0)}%',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (inProgressTasks > 0)
                            PieChartSectionData(
                              color: Colors.orange,
                              value: inProgressTasks.toDouble(),
                              title: '${((inProgressTasks / totalTasks) * 100).toStringAsFixed(0)}%',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (pendingTasks > 0)
                            PieChartSectionData(
                              color: Colors.blue,
                              value: pendingTasks.toDouble(),
                              title: '${((pendingTasks / totalTasks) * 100).toStringAsFixed(0)}%',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Hoàn thành', Colors.green, completedTasks),
                        _buildLegendItem('Đang thực hiện', Colors.orange, inProgressTasks),
                        _buildLegendItem('Chờ thực hiện', Colors.blue, pendingTasks),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ($count)',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResourceOverview() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài nguyên',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Tổng tài nguyên: ${_resources.length}'),
            const SizedBox(height: 8),
            if (_resources.isNotEmpty) ...[
              const Text('Phân bố theo loại:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              ..._getResourceTypeDistribution().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getResourceTypeLabel(entry.key),
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.resourceManagement,
                    arguments: {'projectId': widget.projectId},
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Quản lý tài nguyên',
                  style: TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBudgetOverview() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ngân sách',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_budget != null) ...[
              Text(
                'Tổng: ${NumberFormat.compact().format(_budget!.totalBudget)} VND',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Đã chi: ${NumberFormat.compact().format(_budget!.spentBudget)} VND',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Còn lại: ${NumberFormat.compact().format(_budget!.getRemainingBudget())} VND',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _budget!.totalBudget > 0 
                    ? _budget!.spentBudget / _budget!.totalBudget 
                    : 0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _budget!.spentBudget > _budget!.totalBudget 
                      ? Colors.red 
                      : AppColors.primary,
                ),
              ),
            ] else ...[
              const Text('Chưa có ngân sách', style: TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.reportsAnalytics,
                    arguments: {'projectId': widget.projectId},
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Xem báo cáo',
                  style: TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEnterpriseFeatures() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tính năng Enterprise',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                _buildFeatureCard(
                  'Quản lý\nVai trò',
                  Icons.admin_panel_settings,
                  Colors.blue,
                  () => Navigator.pushNamed(context, AppRoutes.roleManagement),
                ),
                _buildFeatureCard(
                  'Quản lý\nTài nguyên',
                  Icons.inventory,
                  Colors.green,
                  () => Navigator.pushNamed(
                    context,
                    AppRoutes.resourceManagement,
                    arguments: {'projectId': widget.projectId},
                  ),
                ),
                _buildFeatureCard(
                  'Báo cáo\n& Phân tích',
                  Icons.analytics,
                  Colors.orange,
                  () => Navigator.pushNamed(
                    context,
                    AppRoutes.reportsAnalytics,
                    arguments: {'projectId': widget.projectId},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Map<String, int> _getResourceTypeDistribution() {
    Map<String, int> distribution = {};
    for (var resource in _resources) {
      distribution[resource.type] = (distribution[resource.type] ?? 0) + 1;
    }
    return distribution;
  }
  
  String _getResourceTypeLabel(String type) {
    switch (type) {
      case 'human': return 'Nhân lực';
      case 'equipment': return 'Thiết bị';
      case 'material': return 'Vật liệu';
      case 'other': return 'Khác';
      default: return type;
    }
  }
  
  // Widget hiển thị bộ lọc nhiệm vụ
  Widget _buildTaskFilters() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lọc nhiệm vụ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Bộ lọc "Nhiệm vụ của tôi"
            InkWell(
              onTap: _toggleMyTasksFilter,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _showMyTasksOnly ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _showMyTasksOnly ? AppColors.primary : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: _showMyTasksOnly ? AppColors.primary : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Chỉ hiện nhiệm vụ của tôi',
                      style: TextStyle(
                        color: _showMyTasksOnly ? AppColors.primary : Colors.black,
                        fontWeight: _showMyTasksOnly ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _showMyTasksOnly,
                      onChanged: (value) {
                        setState(() {
                          _showMyTasksOnly = value;
                          _loadData();
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Trạng thái:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hoàn thành', 'completed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Đang thực hiện', 'in_progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Chờ thực hiện', 'pending'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget hiển thị chip lọc
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedTaskFilter == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        _changeStatusFilter(value);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  // Widget hiển thị danh sách nhiệm vụ
  Widget _buildTasksList() {
    if (_filteredTasks.isEmpty) {
      return Card(
        elevation: 4,
        child: SizedBox(
          height: 100,
          child: Center(
            child: Text(
              _showMyTasksOnly 
                  ? 'Không có nhiệm vụ nào được giao cho bạn' 
                  : 'Không có nhiệm vụ nào',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách nhiệm vụ (${_filteredTasks.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.taskAssignment,
                      arguments: {
                        'projectId': widget.projectId,
                        'projectName': 'Dự án', // TODO: Get project name
                      },
                    );
                  },
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredTasks.length > 5 ? 5 : _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return _buildTaskListItem(task);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget hiển thị một nhiệm vụ trong danh sách
  Widget _buildTaskListItem(Task task) {
    Color statusColor;
    IconData statusIcon;
    
    switch (task.status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
    }
    
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Hạn: ${task.deadlineDate}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Text(
          _getStatusLabel(task.status),
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        onTap: () {
          _showTaskDetailDialog(task);
        },
      ),
    );
  }
  
  // Hiển thị dialog chi tiết nhiệm vụ
  void _showTaskDetailDialog(Task task) {
    final currentUserEmail = Auth.auth.currentUser?.email;
    final isAssignedToMe = currentUserEmail != null && task.members.contains(currentUserEmail);
    final bool canUpdateStatus = isAssignedToMe && task.status.toLowerCase() != 'completed';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(task.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusLabel(task.status),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mô tả:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task.description),
              const SizedBox(height: 16),
              const Text('Thời hạn:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${task.deadlineDate} ${task.deadlineTime}'),
              const SizedBox(height: 16),
              const Text('Người thực hiện:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task.members.join(', ')),
              if (canUpdateStatus) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Cập nhật trạng thái:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateTaskStatus(task, 'completed');
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Đánh dấu hoàn thành'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
  
  // Cập nhật trạng thái nhiệm vụ
  Future<void> _updateTaskStatus(Task task, String newStatus) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Tạo bản sao của task với trạng thái mới
      final updatedTask = task.copyWith(status: newStatus);
      
      // Cập nhật task
      final success = await _taskRepository.updateTask(updatedTask);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật trạng thái thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Tải lại dữ liệu từ Firebase
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật trạng thái'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Lấy màu dựa trên trạng thái
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
  
  // Hàm lấy nhãn trạng thái từ mã trạng thái
  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Hoàn thành';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'pending':
        return 'Chờ thực hiện';
      default:
        return status;
    }
  }

  // Tạo nhiệm vụ mẫu để kiểm tra
  Future<void> _createTestTask() async {
    final currentUserEmail = Auth.auth.currentUser?.email;
    if (currentUserEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chưa đăng nhập')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final taskId = 'test-${DateTime.now().millisecondsSinceEpoch}';
      final task = Task(
        id: taskId,
        title: 'Nhiệm vụ kiểm tra',
        description: 'Nhiệm vụ này được tạo để kiểm tra tính năng lọc',
        deadlineDate: '01/01/2024',
        deadlineTime: '12:00',
        members: [currentUserEmail],
        status: 'pending',
        projectName: 'Test Project',
        projectId: widget.projectId,
        priority: 'normal',
      );
      
      await _taskRepository.createTask(task);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo nhiệm vụ kiểm tra'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
} 