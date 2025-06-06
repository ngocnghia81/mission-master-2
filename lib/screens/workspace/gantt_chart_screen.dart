import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/data/models/task_model.dart';

class GanttChartScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const GanttChartScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<GanttChartScreen> createState() => _GanttChartScreenState();
}

class _GanttChartScreenState extends State<GanttChartScreen> {
  bool _isLoading = true;
  List<Task> _tasks = [];
  late DateTime _startDate;
  late DateTime _endDate;
  final int _daysToShow = 30;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy tất cả các task trong project
      final QuerySnapshot taskSnapshot = await FirebaseFirestore.instance
          .collection('Tasks')
          .doc(widget.projectId)
          .collection('projectTasks')
          .get();
      
      List<Task> tasks = [];
      for (var doc in taskSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        List<String> members = [];
        if (data['Members'] != null) {
          if (data['Members'] is List) {
            members = List<String>.from(data['Members']);
          } else if (data['Members'] is String) {
            members = [data['Members'] as String];
          }
        }
        
        tasks.add(Task(
          id: doc.id,
          title: data['taskName'] ?? '',
          description: data['description'] ?? '',
          deadlineDate: data['deadlineDate'] ?? '',
          deadlineTime: data['deadlineTime'] ?? '',
          members: members,
          status: data['status'] ?? 'none',
          projectName: data['projectName'] ?? '',
          projectId: widget.projectId,
          priority: data['priority'] ?? 'normal',
        ));
      }
      
      // Tính toán ngày bắt đầu và kết thúc cho biểu đồ Gantt
      if (tasks.isNotEmpty) {
        // Mặc định bắt đầu từ ngày hiện tại
        _startDate = DateTime.now();
        _endDate = _startDate.add(Duration(days: _daysToShow));
        
        // Tìm ngày sớm nhất và muộn nhất trong các task
        for (var task in tasks) {
          try {
            final parts = task.deadlineDate.split('/');
            if (parts.length == 3) {
              final taskDate = DateTime(
                int.parse(parts[2]), // năm
                int.parse(parts[1]), // tháng
                int.parse(parts[0]), // ngày
              );
              
              if (taskDate.isBefore(_startDate)) {
                _startDate = taskDate;
              }
              
              if (taskDate.isAfter(_endDate)) {
                _endDate = taskDate;
              }
            }
          } catch (e) {
            print('Error parsing date: $e');
          }
        }
        
        // Đảm bảo hiển thị ít nhất 30 ngày
        final difference = _endDate.difference(_startDate).inDays;
        if (difference < _daysToShow) {
          _endDate = _startDate.add(Duration(days: _daysToShow));
        }
      } else {
        _startDate = DateTime.now();
        _endDate = _startDate.add(Duration(days: _daysToShow));
      }
      
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Biểu đồ Gantt - ${widget.projectName}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildGanttChart(),
    );
  }

  Widget _buildGanttChart() {
    if (_tasks.isEmpty) {
      return Center(
        child: Text(
          'Không có nhiệm vụ nào trong dự án này',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    final totalDays = _endDate.difference(_startDate).inDays + 1;
    final dayWidth = 60.0;
    final headerHeight = 60.0;
    final rowHeight = 70.0;
    final taskNameWidth = 150.0;

    return Column(
      children: [
        // Header với các ngày
        Container(
          height: headerHeight,
          child: Row(
            children: [
              // Cột tên nhiệm vụ
              Container(
                width: taskNameWidth,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    'Nhiệm vụ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              
              // Các cột ngày
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(totalDays, (index) {
                      final day = _startDate.add(Duration(days: index));
                      final isWeekend = day.weekday == 6 || day.weekday == 7;
                      final isToday = _isSameDay(day, DateTime.now());
                      
                      return Container(
                        width: dayWidth,
                        decoration: BoxDecoration(
                          color: isWeekend
                              ? Colors.grey.shade100
                              : isToday
                                  ? Colors.blue.shade50
                                  : Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd/MM').format(day),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _getDayOfWeek(day),
                              style: TextStyle(
                                fontSize: 10,
                                color: isWeekend ? Colors.red : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Nội dung biểu đồ Gantt
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalController,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cột tên nhiệm vụ
                Container(
                  width: taskNameWidth,
                  child: Column(
                    children: _tasks.map((task) {
                      return Container(
                        height: rowHeight,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Deadline: ${task.deadlineDate}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Phần biểu đồ Gantt
                Expanded(
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: dayWidth * totalDays,
                      child: Stack(
                        children: [
                          // Lưới nền
                          Column(
                            children: _tasks.map((task) {
                              return Container(
                                height: rowHeight,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                              );
                            }).toList(),
                          ),
                          
                          // Thanh tiến độ cho từng nhiệm vụ
                          ..._buildTaskBars(),
                          
                          // Đường chỉ thị ngày hiện tại
                          _buildTodayIndicator(totalDays, rowHeight * _tasks.length),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTaskBars() {
    List<Widget> bars = [];
    double top = 0;
    final rowHeight = 70.0;
    final dayWidth = 60.0;

    for (var task in _tasks) {
      try {
        final parts = task.deadlineDate.split('/');
        if (parts.length == 3) {
          final taskDate = DateTime(
            int.parse(parts[2]), // năm
            int.parse(parts[1]), // tháng
            int.parse(parts[0]), // ngày
          );
          
          // Tính vị trí của thanh tiến độ
          final daysFromStart = taskDate.difference(_startDate).inDays;
          final left = daysFromStart * dayWidth;
          
          // Xác định màu dựa trên trạng thái
          Color barColor;
          switch (task.status) {
            case 'completed':
              barColor = AppColors.taskCompleted;
              break;
            case 'in progress':
              barColor = AppColors.taskInProgress;
              break;
            default:
              barColor = AppColors.taskPending;
              break;
          }
          
          // Tạo thanh tiến độ
          bars.add(
            Positioned(
              top: top + 10, // Căn giữa trong hàng
              left: left,
              child: Container(
                width: dayWidth,
                height: rowHeight - 20,
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: barColor),
                ),
                child: Center(
                  child: Icon(
                    _getStatusIcon(task.status),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error creating task bar: $e');
      }
      
      top += rowHeight;
    }
    
    return bars;
  }

  Widget _buildTodayIndicator(int totalDays, double height) {
    final dayWidth = 60.0;
    final today = DateTime.now();
    
    // Kiểm tra xem ngày hiện tại có nằm trong khoảng hiển thị không
    if (today.isBefore(_startDate) || today.isAfter(_endDate)) {
      return SizedBox();
    }
    
    final daysFromStart = today.difference(_startDate).inDays;
    final left = daysFromStart * dayWidth + (dayWidth / 2);
    
    return Positioned(
      left: left,
      top: 0,
      child: Container(
        width: 2,
        height: height,
        color: Colors.red,
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in progress':
        return Icons.timelapse;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _getDayOfWeek(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 7:
        return 'CN';
      default:
        return '';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
