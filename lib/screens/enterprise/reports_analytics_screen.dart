import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/models/report_model.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/models/resource_model.dart';
import 'package:mission_master/data/repositories/report_repository.dart';
import 'package:mission_master/data/repositories/resource_repository.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  final String projectId;
  
  const ReportsAnalyticsScreen({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  _ReportsAnalyticsScreenState createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> with SingleTickerProviderStateMixin {
  final ReportRepository _reportRepository = ReportRepository();
  final ResourceRepository _resourceRepository = ResourceRepository();
  late final TaskRepository _taskRepository;
  
  List<Report> _reports = [];
  List<Task> _tasks = [];
  List<Resource> _resources = [];
  Budget? _budget;
  bool _isLoading = true;
  late TabController _tabController;
  
  ProjectStatusReport? _projectStatusReport;
  ResourceUsageReport? _resourceUsageReport;
  BudgetReport? _budgetReport;
  PerformanceReport? _performanceReport;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeAndLoadData();
  }
  
  Future<void> _initializeAndLoadData() async {
    final prefs = await SharedPreferences.getInstance();
    _taskRepository = TaskRepository(
      taskDataProvider: TaskDataProvider(prefs),
    );
    await _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('DEBUG: Loading data for projectId: ${widget.projectId}');
      
      // Tải dữ liệu cơ bản
      final reports = await _reportRepository.getProjectReports(widget.projectId);
      final tasks = await _taskRepository.getTasksByProjectId(widget.projectId);
      final resources = await _resourceRepository.getProjectResources(widget.projectId);
      
      print('DEBUG: Loaded ${reports.length} reports');
      print('DEBUG: Loaded ${tasks.length} tasks');
      print('DEBUG: Loaded ${resources.length} resources');
      
      // Debug hiển thị thông tin tasks
      if (tasks.isNotEmpty) {
        print('DEBUG: First task: ${tasks.first.title}, status: ${tasks.first.status}');
        for (var task in tasks) {
          print('DEBUG: Task "${task.title}" - Status: ${task.status}');
        }
      } else {
        print('DEBUG: No tasks found for project ${widget.projectId}');
      }
      
      // Đồng bộ ngân sách trước khi lấy dữ liệu
      await _resourceRepository.syncBudgetWithItems(widget.projectId);
      final budget = await _resourceRepository.getProjectBudget(widget.projectId);
      
      print('DEBUG: Budget total: ${budget?.totalBudget}');
      
      setState(() {
        _reports = reports;
        _tasks = tasks;
        _resources = resources;
        _budget = budget;
      });
      
      // Tạo báo cáo phân tích
      await _generateAnalytics();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể tải dữ liệu: $e');
    }
  }
  
  Future<void> _generateAnalytics() async {
    try {
      // Tạo báo cáo trạng thái dự án
      _projectStatusReport = _generateProjectStatusReport();
      
      // Tạo báo cáo sử dụng tài nguyên
      _resourceUsageReport = _generateResourceUsageReport();
      
      // Tạo báo cáo ngân sách
      if (_budget != null) {
        _budgetReport = _generateBudgetReport();
      }
      
      // Tạo báo cáo hiệu suất
      _performanceReport = _generatePerformanceReport();
    } catch (e) {
      print('Error generating analytics: $e');
    }
  }
  
  ProjectStatusReport _generateProjectStatusReport() {
    print('DEBUG: Generating project status report with ${_tasks.length} tasks');
    
    int totalTasks = _tasks.length;
    int completedTasks = _tasks.where((task) => task.status == 'completed').length;
    int inProgressTasks = _tasks.where((task) => task.status == 'in_progress').length;
    int pendingTasks = _tasks.where((task) => task.status == 'pending').length;
    int overdueTasks = _tasks.where((task) => 
        task.status != 'completed' && 
        task.dueDate != null && 
        task.dueDate!.isBefore(DateTime.now())
    ).length;
    
    print('DEBUG: Task counts - Total: $totalTasks, Completed: $completedTasks, InProgress: $inProgressTasks, Pending: $pendingTasks, Overdue: $overdueTasks');
    
    double completionPercentage = totalTasks > 0 
        ? (completedTasks / totalTasks) * 100 
        : 0.0;
    
    // Phân tích nhiệm vụ theo thành viên
    Map<String, int> tasksByMember = {};
    for (var task in _tasks) {
      if (task.assignedTo != null && task.assignedTo!.isNotEmpty) {
        for (var member in task.assignedTo!) {
          tasksByMember[member] = (tasksByMember[member] ?? 0) + 1;
        }
      }
    }
    
    // Phân tích nhiệm vụ theo mức độ ưu tiên
    Map<String, int> tasksByPriority = {};
    for (var task in _tasks) {
      tasksByPriority[task.priority] = (tasksByPriority[task.priority] ?? 0) + 1;
    }
    
    print('DEBUG: Tasks by member: $tasksByMember');
    print('DEBUG: Tasks by priority: $tasksByPriority');
    print('DEBUG: Completion percentage: $completionPercentage');
    
    return ProjectStatusReport(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      inProgressTasks: inProgressTasks,
      pendingTasks: pendingTasks,
      overdueTasks: overdueTasks,
      completionPercentage: completionPercentage,
      tasksByMember: tasksByMember,
      tasksByPriority: tasksByPriority,
      recentActivities: [], // Có thể thêm logic để lấy hoạt động gần đây
    );
  }
  
  ResourceUsageReport _generateResourceUsageReport() {
    double totalResourceCost = 0;
    for (var resource in _resources) {
      totalResourceCost += resource.getTotalCost();
    }
    
    Map<String, double> costByResourceType = {};
    for (var resource in _resources) {
      costByResourceType[resource.type] = 
          (costByResourceType[resource.type] ?? 0.0) + resource.getTotalCost();
    }
    
    List<Map<String, dynamic>> resourceUtilization = [];
    for (var resource in _resources) {
      resourceUtilization.add({
        'resourceId': resource.id,
        'resourceName': resource.name,
        'utilizationRate': resource.availableUnits > 0 
            ? (resource.allocatedUnits / resource.availableUnits) * 100 
            : 0.0,
      });
    }
    
    return ResourceUsageReport(
      totalResourceCost: totalResourceCost,
      costByResourceType: costByResourceType,
      costByTask: {}, // Có thể thêm logic tính chi phí theo nhiệm vụ
      resourceUtilization: resourceUtilization,
      resourceEfficiency: {}, // Có thể thêm logic tính hiệu quả
    );
  }
  
  BudgetReport _generateBudgetReport() {
    print('DEBUG: Generating budget report...');
    
    if (_budget == null) {
      print('DEBUG: Budget is null, returning empty report');
      return BudgetReport(
        totalBudget: 0,
        allocatedBudget: 0,
        spentBudget: 0,
        remainingBudget: 0,
        spendingByCategory: {},
        spendingTrend: {},
        budgetForecast: [],
        isOverBudget: false,
        burnRate: 0,
      );
    }
    
    print('DEBUG: Budget data - Total: ${_budget!.totalBudget}, Spent: ${_budget!.spentBudget}, Allocated: ${_budget!.allocatedBudget}');
    print('DEBUG: Budget category allocation: ${_budget!.categoryAllocation}');
    
    final report = BudgetReport(
      totalBudget: _budget!.totalBudget,
      allocatedBudget: _budget!.allocatedBudget,
      spentBudget: _budget!.spentBudget,
      remainingBudget: _budget!.getRemainingBudget(),
      spendingByCategory: _budget!.categoryAllocation,
      spendingTrend: {}, // Có thể thêm logic xu hướng chi tiêu
      budgetForecast: [], // Có thể thêm logic dự báo
      isOverBudget: _budget!.spentBudget > _budget!.totalBudget,
      burnRate: _budget!.totalBudget > 0 
          ? (_budget!.spentBudget / _budget!.totalBudget) * 100 
          : 0.0,
    );
    
    print('DEBUG: Generated budget report - SpendingByCategory: ${report.spendingByCategory}');
    return report;
  }
  
  PerformanceReport _generatePerformanceReport() {
    Map<String, double> memberProductivity = {};
    Map<String, int> taskCompletionTime = {};
    Map<String, double> memberEfficiency = {};
    
    // Tính hiệu suất thành viên
    for (var task in _tasks.where((t) => t.status == 'completed')) {
      if (task.assignedTo != null && task.assignedTo!.isNotEmpty) {
        for (var member in task.assignedTo!) {
          memberProductivity[member] = (memberProductivity[member] ?? 0.0) + 1.0;
          
          if (task.completedAt != null && task.startedAt != null) {
            int completionTime = task.completedAt!.difference(task.startedAt!).inHours;
            taskCompletionTime[task.id] = completionTime;
          }
        }
      }
    }
    
    double averageCompletionTime = taskCompletionTime.isNotEmpty
        ? taskCompletionTime.values.reduce((a, b) => a + b) / taskCompletionTime.length
        : 0.0;
    
    return PerformanceReport(
      memberProductivity: memberProductivity,
      taskCompletionTime: taskCompletionTime,
      averageTaskCompletionTime: averageCompletionTime,
      memberEfficiency: memberEfficiency,
      performanceTrend: [],
      improvementSuggestions: [],
    );
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
  
  Future<void> _generateNewReport(String reportType) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      String? reportId;
      final now = DateTime.now();
      final reportTitle = 'Báo cáo ${_getReportTypeLabel(reportType)} - ${DateFormat('dd/MM/yyyy').format(now)}';
      
      switch (reportType) {
        case 'project_status':
          reportId = await _reportRepository.generateProjectStatusReport(
            widget.projectId,
            reportTitle,
            'Báo cáo trạng thái dự án được tạo tự động',
            'current_user', // Thay bằng user ID thực tế
            now,
            _tasks,
            [],
          );
          break;
        case 'resource_usage':
          final allocations = await _resourceRepository.getResourceAllocations(widget.projectId);
          final taskMap = {for (var task in _tasks) task.id: task};
          reportId = await _reportRepository.generateResourceUsageReport(
            widget.projectId,
            reportTitle,
            'Báo cáo sử dụng tài nguyên được tạo tự động',
            'current_user',
            now,
            _resources,
            allocations,
            taskMap,
          );
          break;
        case 'budget':
          if (_budget != null) {
            reportId = await _reportRepository.generateBudgetReport(
              widget.projectId,
              reportTitle,
              'Báo cáo ngân sách được tạo tự động',
              'current_user',
              now,
              _budget!,
              {},
              [],
            );
          }
          break;
        case 'performance':
          final completedTasks = _tasks.where((t) => t.status == 'completed').toList();
          reportId = await _reportRepository.generatePerformanceReport(
            widget.projectId,
            reportTitle,
            'Báo cáo hiệu suất được tạo tự động',
            'current_user',
            now,
            completedTasks,
            {},
            {},
            {},
            [],
          );
          break;
      }
      
      if (reportId != null) {
        _showSuccessSnackBar('Tạo báo cáo thành công');
        await _loadData();
      } else {
        _showErrorSnackBar('Không thể tạo báo cáo');
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi khi tạo báo cáo: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _getReportTypeLabel(String type) {
    switch (type) {
      case 'project_status': return 'Trạng thái dự án';
      case 'resource_usage': return 'Sử dụng tài nguyên';
      case 'budget': return 'Ngân sách';
      case 'performance': return 'Hiệu suất';
      default: return 'Khác';
    }
  }
  
  Widget _buildProjectStatusTab() {
    if (_projectStatusReport == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }
    
    final report = _projectStatusReport!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Trạng thái dự án',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _generateNewReport('project_status'),
                icon: const Icon(Icons.add),
                label: const Text('Tạo báo cáo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tổng quan nhiệm vụ
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng quan nhiệm vụ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Tổng số', 
                          report.totalTasks.toString(), 
                          Icons.assignment,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Hoàn thành', 
                          report.completedTasks.toString(), 
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Đang thực hiện', 
                          report.inProgressTasks.toString(), 
                          Icons.schedule,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Quá hạn', 
                          report.overdueTasks.toString(), 
                          Icons.warning,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: report.completionPercentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      report.completionPercentage > 75 ? Colors.green : 
                      report.completionPercentage > 50 ? Colors.orange : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tiến độ hoàn thành: ${report.completionPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Biểu đồ tròn trạng thái nhiệm vụ
          Card(
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
                    child: report.totalTasks > 0 ? PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(enabled: false),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (report.completedTasks > 0)
                            PieChartSectionData(
                              color: Colors.green,
                              value: report.completedTasks.toDouble(),
                              title: '${report.completedTasks}',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (report.inProgressTasks > 0)
                            PieChartSectionData(
                              color: Colors.orange,
                              value: report.inProgressTasks.toDouble(),
                              title: '${report.inProgressTasks}',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (report.pendingTasks > 0)
                            PieChartSectionData(
                              color: Colors.blue,
                              value: report.pendingTasks.toDouble(),
                              title: '${report.pendingTasks}',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (report.overdueTasks > 0)
                            PieChartSectionData(
                              color: Colors.red,
                              value: report.overdueTasks.toDouble(),
                              title: '${report.overdueTasks}',
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ) : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assessment, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'Không có dữ liệu nhiệm vụ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Hãy tạo nhiệm vụ mới để xem báo cáo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend
                  Wrap(
                    spacing: 16,
                    children: [
                      _buildLegendItem('Hoàn thành', Colors.green),
                      _buildLegendItem('Đang thực hiện', Colors.orange),
                      _buildLegendItem('Chờ thực hiện', Colors.blue),
                      _buildLegendItem('Quá hạn', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Nhiệm vụ theo thành viên
          if (report.tasksByMember.isNotEmpty)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhiệm vụ theo thành viên',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...report.tasksByMember.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(entry.key),
                            ),
                            Expanded(
                              flex: 3,
                              child: LinearProgressIndicator(
                                value: entry.value / report.totalTasks,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${entry.value}'),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildResourceUsageTab() {
    if (_resourceUsageReport == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }
    
    final report = _resourceUsageReport!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Sử dụng tài nguyên',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _generateNewReport('resource_usage'),
                icon: const Icon(Icons.add),
                label: const Text('Tạo báo cáo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tổng chi phí tài nguyên
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng chi phí tài nguyên',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'VND').format(report.totalResourceCost),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Chi phí theo loại tài nguyên
          if (report.costByResourceType.isNotEmpty)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi phí theo loại tài nguyên',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: report.costByResourceType.values.isNotEmpty 
                              ? report.costByResourceType.values.reduce((a, b) => a > b ? a : b)
                              : 100,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  final index = value.toInt();
                                  final types = report.costByResourceType.keys.toList();
                                  if (index < types.length) {
                                    return Text(
                                      _getResourceTypeLabel(types[index]),
                                      style: const TextStyle(fontSize: 12),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  return Text(
                                    NumberFormat.compact().format(value),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: report.costByResourceType.entries.toList().asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.value,
                                  color: AppColors.primary,
                                  width: 16,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 20),
          
          // Tỷ lệ sử dụng tài nguyên
          if (report.resourceUtilization.isNotEmpty)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tỷ lệ sử dụng tài nguyên',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...report.resourceUtilization.map((resource) {
                      final utilizationRate = resource['utilizationRate'] as double;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(resource['resourceName'] as String),
                                Text('${utilizationRate.toStringAsFixed(1)}%'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: utilizationRate / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                utilizationRate > 90 ? Colors.red :
                                utilizationRate > 70 ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildBudgetTab() {
    if (_budgetReport == null) {
      return const Center(child: Text('Không có dữ liệu ngân sách'));
    }
    
    final report = _budgetReport!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Báo cáo ngân sách',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _generateNewReport('budget'),
                icon: const Icon(Icons.add),
                label: const Text('Tạo báo cáo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tổng quan ngân sách
          Row(
            children: [
              Expanded(
                child: _buildBudgetCard(
                  'Tổng ngân sách',
                  NumberFormat.currency(locale: 'vi_VN', symbol: 'VND').format(report.totalBudget),
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBudgetCard(
                  'Đã chi tiêu',
                  NumberFormat.currency(locale: 'vi_VN', symbol: 'VND').format(report.spentBudget),
                  Icons.money_off,
                  report.isOverBudget ? Colors.red : Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBudgetCard(
                  'Còn lại',
                  NumberFormat.currency(locale: 'vi_VN', symbol: 'VND').format(report.remainingBudget),
                  Icons.savings,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Tỷ lệ burn rate
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tỷ lệ tiêu hao ngân sách',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: report.burnRate / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      report.burnRate > 90 ? Colors.red :
                      report.burnRate > 70 ? Colors.orange : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Burn Rate: ${report.burnRate.toStringAsFixed(1)}%',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (report.isOverBudget)
                        const Text(
                          'VƯỢT NGÂN SÁCH',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Chi tiêu theo danh mục
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chi tiêu theo danh mục',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: report.spendingByCategory.isNotEmpty && 
                           report.spendingByCategory.values.any((value) => value > 0) 
                        ? PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(enabled: false),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: report.spendingByCategory.entries
                                  .where((entry) => entry.value > 0)
                                  .map((entry) {
                                return PieChartSectionData(
                                  color: _getCategoryColor(entry.key),
                                  value: entry.value,
                                  title: NumberFormat.compact().format(entry.value),
                                  radius: 50,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[400]),
                                SizedBox(height: 16),
                                Text(
                                  'Chưa có chi tiêu theo danh mục',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Dữ liệu sẽ hiển thị sau khi có giao dịch ngân sách',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Legend cho danh mục
                  if (report.spendingByCategory.isNotEmpty)
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: report.spendingByCategory.entries.map((entry) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(entry.key),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getCategoryDisplayName(entry.key),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              NumberFormat.compact().format(entry.value),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceTab() {
    if (_performanceReport == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }
    
    final report = _performanceReport!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Báo cáo hiệu suất',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _generateNewReport('performance'),
                icon: const Icon(Icons.add),
                label: const Text('Tạo báo cáo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Thời gian hoàn thành trung bình
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thời gian hoàn thành trung bình',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${report.averageTaskCompletionTime.toStringAsFixed(1)} giờ',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Năng suất thành viên
          if (report.memberProductivity.isNotEmpty)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Năng suất thành viên',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...report.memberProductivity.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                entry.key,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: LinearProgressIndicator(
                                value: entry.value / (report.memberProductivity.values.isNotEmpty 
                                    ? report.memberProductivity.values.reduce((a, b) => a > b ? a : b)
                                    : 1),
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.value.toStringAsFixed(0)} nhiệm vụ',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBudgetCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
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
  
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'human':
      case 'development':
        return Colors.blue[600]!;
      case 'equipment':
        return Colors.green[600]!;
      case 'material':
        return Colors.orange[600]!;
      case 'design':
        return Colors.purple[600]!;
      case 'testing':
        return Colors.red[600]!;
      case 'marketing':
        return Colors.pink[600]!;
      case 'other':
        return Colors.grey[600]!;
      default:
        // Generate color based on string hash for consistency
        final hash = category.hashCode;
        final colors = [
          Colors.indigo[600]!,
          Colors.teal[600]!,
          Colors.amber[600]!,
          Colors.deepPurple[600]!,
          Colors.cyan[600]!,
          Colors.lime[600]!,
        ];
        return colors[hash.abs() % colors.length];
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'human': return 'Nhân lực';
      case 'equipment': return 'Thiết bị';
      case 'material': return 'Vật liệu';
      case 'development': return 'Phát triển';
      case 'design': return 'Thiết kế';
      case 'testing': return 'Kiểm thử';
      case 'marketing': return 'Marketing';
      case 'other': return 'Khác';
      default: return category.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo & Phân tích'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Trạng thái', icon: Icon(Icons.dashboard)),
            Tab(text: 'Tài nguyên', icon: Icon(Icons.inventory)),
            Tab(text: 'Ngân sách', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Hiệu suất', icon: Icon(Icons.trending_up)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProjectStatusTab(),
                _buildResourceUsageTab(),
                _buildBudgetTab(),
                _buildPerformanceTab(),
              ],
            ),
    );
  }
} 