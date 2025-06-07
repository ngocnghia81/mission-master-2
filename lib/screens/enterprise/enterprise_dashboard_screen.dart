import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/models/resource_model.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:mission_master/data/repositories/resource_repository.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
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
  List<Resource> _resources = [];
  Budget? _budget;
  bool _isLoading = true;
  
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
      final tasks = await _taskRepository.getTasksByProjectId(widget.projectId);
      final resources = await _resourceRepository.getProjectResources(widget.projectId);
      
      // Đồng bộ ngân sách trước khi lấy dữ liệu
      await _resourceRepository.syncBudgetWithItems(widget.projectId);
      final budget = await _resourceRepository.getProjectBudget(widget.projectId);
      
      setState(() {
        _tasks = tasks;
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
  
  @override
  Widget build(BuildContext context) {
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
                  // Tổng quan
                  _buildOverviewSection(),
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
    int totalTasks = _tasks.length;
    int completedTasks = _tasks.where((task) => task.status == 'completed').length;
    int activeTasks = _tasks.where((task) => task.status == 'in_progress').length;
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
    if (_tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    
    int completedTasks = _tasks.where((task) => task.status == 'completed').length;
    int inProgressTasks = _tasks.where((task) => task.status == 'in_progress').length;
    int pendingTasks = _tasks.where((task) => task.status == 'pending').length;
    int totalTasks = _tasks.length;
    
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
} 