import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';

class StatisticsProvider with ChangeNotifier {
  final _database = locator<Database>();
  bool _isLoading = true;
  double _projectProgress = 0.0;
  
  // Thống kê trạng thái
  int _totalTasks = 0;
  int _pendingTasks = 0;
  int _inProgressTasks = 0;
  int _completedTasks = 0;
  
  // Thống kê ưu tiên
  int _lowPriorityTasks = 0;
  int _normalPriorityTasks = 0;
  int _highPriorityTasks = 0;
  int _urgentPriorityTasks = 0;
  
  // Thống kê hiệu suất thành viên
  Map<String, int> _memberCompletedTasks = {};
  Map<String, int> _memberTotalTasks = {};
  
  // Thống kê thời gian hoàn thành
  int _onTimeCompletions = 0;
  int _lateCompletions = 0;

  // Getters
  bool get isLoading => _isLoading;
  double get projectProgress => _projectProgress;
  int get totalTasks => _totalTasks;
  int get pendingTasks => _pendingTasks;
  int get inProgressTasks => _inProgressTasks;
  int get completedTasks => _completedTasks;
  int get lowPriorityTasks => _lowPriorityTasks;
  int get normalPriorityTasks => _normalPriorityTasks;
  int get highPriorityTasks => _highPriorityTasks;
  int get urgentPriorityTasks => _urgentPriorityTasks;
  Map<String, int> get memberCompletedTasks => _memberCompletedTasks;
  Map<String, int> get memberTotalTasks => _memberTotalTasks;
  int get onTimeCompletions => _onTimeCompletions;
  int get lateCompletions => _lateCompletions;

  Future<void> loadProjectStatistics(String projectId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Lấy tiến độ tổng thể
      final progress = await _database.getProgress(id: projectId);
      
      // Lấy tất cả các task trong dự án
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('Tasks')
          .doc(projectId)
          .collection('projectTasks')
          .get();
      
      // Reset các biến thống kê
      _totalTasks = tasksSnapshot.docs.length;
      _pendingTasks = 0;
      _inProgressTasks = 0;
      _completedTasks = 0;
      
      _lowPriorityTasks = 0;
      _normalPriorityTasks = 0;
      _highPriorityTasks = 0;
      _urgentPriorityTasks = 0;
      
      _memberCompletedTasks = {};
      _memberTotalTasks = {};
      
      _onTimeCompletions = 0;
      _lateCompletions = 0;
      
      final now = DateTime.now();
      
      // Phân tích dữ liệu từ các task
      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        
        // Trạng thái - kiểm tra tất cả các trạng thái có thể
        final status = data['status']?.toString().toLowerCase() ?? '';
        print("Kiểm tra task: ${data['taskName']} - status: '${data['status']}'");
        
        // Danh sách các trạng thái hoàn thành có thể có
        List<String> completedStatuses = ['completed', 'hoàn thành', 'hoàn tất', 'done', 'finish', 'finished'];
        // Danh sách các trạng thái đang thực hiện có thể có
        List<String> inProgressStatuses = ['in progress', 'đang thực hiện', 'in work', 'working'];
        
        if (completedStatuses.contains(status)) {
          _completedTasks++;
          print("✅ Task hoàn thành: ${data['taskName']} - status: '${data['status']}'");
        } else if (inProgressStatuses.contains(status)) {
          _inProgressTasks++;
          print("🔄 Task đang thực hiện: ${data['taskName']} - status: '${data['status']}'");
        } else {
          _pendingTasks++;
          print("⏳ Task chờ xử lý: ${data['taskName']} - status: '${data['status']}'");
        }
        
        // Ưu tiên
        switch (data['priority']?.toString().toLowerCase() ?? 'normal') {
          case 'low':
            _lowPriorityTasks++;
            break;
          case 'high':
            _highPriorityTasks++;
            break;
          case 'urgent':
            _urgentPriorityTasks++;
            break;
          default:
            _normalPriorityTasks++;
            break;
        }
        
        // Thành viên
        final members = List<String>.from(data['Members'] ?? []);
        for (var member in members) {
          _memberTotalTasks[member] = (_memberTotalTasks[member] ?? 0) + 1;
          
          final status = data['status']?.toString().toLowerCase() ?? '';
          // Danh sách các trạng thái hoàn thành có thể có
          List<String> completedStatuses = ['completed', 'hoàn thành', 'hoàn tất', 'done', 'finish', 'finished'];
          
          if (completedStatuses.contains(status)) {
            _memberCompletedTasks[member] = (_memberCompletedTasks[member] ?? 0) + 1;
            print("✅ Thành viên $member hoàn thành task: ${data['taskName']}");
          }
        }
        
        // Đúng hạn hoặc trễ hạn
        final taskStatus = data['status']?.toString().toLowerCase() ?? '';
        // Sử dụng lại danh sách completedStatuses đã định nghĩa ở trên
        if (completedStatuses.contains(taskStatus)) {
          try {
            final dateFormat = data['deadlineDate'].toString().split('/');
            if (dateFormat.length == 3) {
              final deadline = DateTime(
                int.parse(dateFormat[2]), 
                int.parse(dateFormat[1]), 
                int.parse(dateFormat[0])
              );
              
              if (now.isAfter(deadline)) {
                _lateCompletions++;
              } else {
                _onTimeCompletions++;
              }
            }
          } catch (e) {
            print('Lỗi phân tích ngày tháng: $e');
          }
        }
      }
      
      _projectProgress = progress ?? 0.0;
      _isLoading = false;
      notifyListeners();
      
    } catch (e) {
      print('Lỗi khi tải thống kê: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Lấy danh sách thành viên đã sắp xếp theo tỷ lệ hoàn thành
  List<String> getSortedMembers() {
    final sortedMembers = _memberTotalTasks.keys.toList()
      ..sort((a, b) {
        final completionRateA = (_memberCompletedTasks[a] ?? 0) / (_memberTotalTasks[a] ?? 1);
        final completionRateB = (_memberCompletedTasks[b] ?? 0) / (_memberTotalTasks[b] ?? 1);
        return completionRateB.compareTo(completionRateA);
      });
    return sortedMembers;
  }
  
  // Lấy tỷ lệ hoàn thành của một thành viên
  double getMemberCompletionRate(String member) {
    final completed = _memberCompletedTasks[member] ?? 0;
    final total = _memberTotalTasks[member] ?? 1;
    return completed / total;
  }
} 