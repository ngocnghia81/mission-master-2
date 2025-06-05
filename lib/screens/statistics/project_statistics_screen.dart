import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/providers/statistics_provider.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:provider/provider.dart';

class ProjectStatisticsScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectStatisticsScreen({
    Key? key, 
    required this.projectId, 
    required this.projectName,
  }) : super(key: key);

  @override
  _ProjectStatisticsScreenState createState() => _ProjectStatisticsScreenState();
}

class _ProjectStatisticsScreenState extends State<ProjectStatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Tải dữ liệu thống kê khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StatisticsProvider>(context, listen: false)
        .loadProjectStatistics(widget.projectId);
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Làm mới dữ liệu khi màn hình được hiển thị lại
    Provider.of<StatisticsProvider>(context, listen: false)
      .loadProjectStatistics(widget.projectId);
  }

  Future<void> _refreshData() async {
    await Provider.of<StatisticsProvider>(context, listen: false)
      .loadProjectStatistics(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Thống kê dự án'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Trạng thái'),
            Tab(text: 'Thành viên'),
            Tab(text: 'Hiệu suất'),
          ],
        ),
      ),
      body: Consumer<StatisticsProvider>(
        builder: (context, statisticsProvider, child) {
          if (statisticsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Column(
            children: [
              // Nút làm mới dữ liệu
              Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kéo xuống để làm mới hoặc nhấn nút làm mới',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Làm mới'),
                      onPressed: _refreshData,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                        foregroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Project info
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.projectName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tiến độ tổng thể',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: statisticsProvider.projectProgress,
                                backgroundColor: Colors.white38,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Text(
                            '${(statisticsProvider.projectProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshData,
                      child: _buildStatusTab(statisticsProvider),
                    ),
                    RefreshIndicator(
                      onRefresh: _refreshData,
                      child: _buildMembersTab(statisticsProvider),
                    ),
                    RefreshIndicator(
                      onRefresh: _refreshData,
                      child: _buildPerformanceTab(statisticsProvider),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildStatusTab(StatisticsProvider provider) {
    return provider.totalTasks > 0 
      ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Status overview
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng quan trạng thái',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              color: AppColors.taskPending,
                              value: provider.pendingTasks.toDouble(),
                              title: '${(provider.pendingTasks / provider.totalTasks * 100).toInt()}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PieChartSectionData(
                              color: AppColors.taskInProgress,
                              value: provider.inProgressTasks.toDouble(),
                              title: '${(provider.inProgressTasks / provider.totalTasks * 100).toInt()}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PieChartSectionData(
                              color: AppColors.taskCompleted,
                              value: provider.completedTasks.toDouble(),
                              title: '${(provider.completedTasks / provider.totalTasks * 100).toInt()}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          sectionsSpace: 0,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendItem('Chờ xử lý', AppColors.taskPending, provider.pendingTasks),
                        _buildLegendItem('Đang thực hiện', AppColors.taskInProgress, provider.inProgressTasks),
                        _buildLegendItem('Hoàn thành', AppColors.taskCompleted, provider.completedTasks),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Priority distribution
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phân bố mức độ ưu tiên',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: provider.totalTasks.toDouble(),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  String text = '';
                                  switch (value.toInt()) {
                                    case 0:
                                      text = 'Thấp';
                                      break;
                                    case 1:
                                      text = 'Thường';
                                      break;
                                    case 2:
                                      text = 'Cao';
                                      break;
                                    case 3:
                                      text = 'Khẩn cấp';
                                      break;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: provider.lowPriorityTasks.toDouble(),
                                  color: Colors.blue,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                  toY: provider.normalPriorityTasks.toDouble(),
                                  color: Colors.grey,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 2,
                              barRods: [
                                BarChartRodData(
                                  toY: provider.highPriorityTasks.toDouble(),
                                  color: Colors.orange,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 3,
                              barRods: [
                                BarChartRodData(
                                  toY: provider.urgentPriorityTasks.toDouble(),
                                  color: Colors.red,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      : const Center(
          child: Text('Chưa có công việc nào trong dự án'),
        );
  }
  
  Widget _buildMembersTab(StatisticsProvider provider) {
    final sortedMembers = provider.getSortedMembers();
    
    return provider.memberTotalTasks.isNotEmpty
      ? ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: sortedMembers.length,
          itemBuilder: (context, index) {
            final member = sortedMembers[index];
            final completedTasks = provider.memberCompletedTasks[member] ?? 0;
            final totalTasks = provider.memberTotalTasks[member] ?? 0;
            final completionRate = completedTasks / totalTasks;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryColor,
                          child: Text(
                            member.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Hoàn thành: $completedTasks/$totalTasks công việc',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _getCompletionColor(completionRate),
                          child: Text(
                            '${(completionRate * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: completionRate,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getCompletionColor(completionRate),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        )
      : const Center(
          child: Text('Chưa có thành viên nào trong dự án'),
        );
  }
  
  Widget _buildPerformanceTab(StatisticsProvider provider) {
    return provider.totalTasks > 0
      ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Time performance
            if (provider.completedTasks > 0) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thời gian hoàn thành',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                color: Colors.green,
                                value: provider.onTimeCompletions.toDouble(),
                                title: '${(provider.onTimeCompletions / provider.completedTasks * 100).toInt()}%',
                                radius: 60,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              PieChartSectionData(
                                color: Colors.red,
                                value: provider.lateCompletions.toDouble(),
                                title: '${(provider.lateCompletions / provider.completedTasks * 100).toInt()}%',
                                radius: 60,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            sectionsSpace: 0,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendItem('Đúng hạn', Colors.green, provider.onTimeCompletions),
                          _buildLegendItem('Trễ hạn', Colors.red, provider.lateCompletions),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Project summary card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng kết dự án',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryItem(
                      'Tổng số công việc', 
                      provider.totalTasks.toString(),
                      Icons.assignment,
                    ),
                    _buildSummaryItem(
                      'Đã hoàn thành', 
                      '${provider.completedTasks} (${(provider.completedTasks / provider.totalTasks * 100).toInt()}%)',
                      Icons.check_circle,
                      color: AppColors.taskCompleted,
                    ),
                    _buildSummaryItem(
                      'Đang thực hiện', 
                      '${provider.inProgressTasks} (${(provider.inProgressTasks / provider.totalTasks * 100).toInt()}%)',
                      Icons.timelapse,
                      color: AppColors.taskInProgress,
                    ),
                    _buildSummaryItem(
                      'Chờ xử lý', 
                      '${provider.pendingTasks} (${(provider.pendingTasks / provider.totalTasks * 100).toInt()}%)',
                      Icons.hourglass_empty,
                      color: AppColors.taskPending,
                    ),
                    const Divider(),
                    _buildSummaryItem(
                      'Số thành viên', 
                      provider.memberTotalTasks.length.toString(),
                      Icons.people,
                    ),
                    _buildSummaryItem(
                      'Công việc ưu tiên cao', 
                      '${provider.highPriorityTasks + provider.urgentPriorityTasks}',
                      Icons.priority_high,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      : const Center(
          child: Text('Chưa có dữ liệu hiệu suất'),
        );
  }
  
  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildSummaryItem(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getCompletionColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }
}