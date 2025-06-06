import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/models/report_model.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/models/resource_model.dart';

class ReportRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'reports';

  ReportRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Lấy danh sách báo cáo của dự án
  Future<List<Report>> getProjectReports(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('projectId', isEqualTo: projectId)
          .orderBy('reportDate', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => Report.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting project reports: $e');
      return [];
    }
  }

  // Lấy báo cáo theo ID
  Future<Report?> getReportById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Report.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Error getting report by ID: $e');
      return null;
    }
  }

  // Tạo báo cáo mới
  Future<String?> createReport(Report report) async {
    try {
      final docRef = await _firestore.collection(_collection).add({
        ...report.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating report: $e');
      return null;
    }
  }

  // Cập nhật báo cáo
  Future<bool> updateReport(Report report) async {
    try {
      await _firestore.collection(_collection).doc(report.id).update({
        ...report.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating report: $e');
      return false;
    }
  }

  // Xóa báo cáo
  Future<bool> deleteReport(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting report: $e');
      return false;
    }
  }

  // Chia sẻ báo cáo với người dùng khác
  Future<bool> shareReport(String reportId, List<String> userIds) async {
    try {
      await _firestore.collection(_collection).doc(reportId).update({
        'isShared': true,
        'sharedWith': FieldValue.arrayUnion(userIds),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error sharing report: $e');
      return false;
    }
  }

  // Hủy chia sẻ báo cáo với người dùng
  Future<bool> unshareReport(String reportId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(reportId).update({
        'sharedWith': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Kiểm tra xem còn chia sẻ với ai không
      final doc = await _firestore.collection(_collection).doc(reportId).get();
      final sharedWith = List<String>.from(doc.data()?['sharedWith'] ?? []);
      
      if (sharedWith.isEmpty) {
        await _firestore.collection(_collection).doc(reportId).update({
          'isShared': false,
        });
      }
      
      return true;
    } catch (e) {
      print('Error unsharing report: $e');
      return false;
    }
  }

  // Tạo báo cáo trạng thái dự án
  Future<String?> generateProjectStatusReport(
    String projectId, 
    String title, 
    String description, 
    String createdBy,
    DateTime reportDate,
    List<Task> tasks,
    List<Map<String, dynamic>> recentActivities,
  ) async {
    try {
      // Phân tích dữ liệu nhiệm vụ
      int totalTasks = tasks.length;
      int completedTasks = tasks.where((task) => task.status == 'completed').length;
      int inProgressTasks = tasks.where((task) => task.status == 'in_progress').length;
      int pendingTasks = tasks.where((task) => task.status == 'pending').length;
      int overdueTasks = tasks.where((task) => 
          task.status != 'completed' && 
          task.dueDate != null && 
          task.dueDate!.isBefore(DateTime.now())
      ).length;
      
      double completionPercentage = totalTasks > 0 
          ? (completedTasks / totalTasks) * 100 
          : 0.0;
      
      // Phân tích nhiệm vụ theo thành viên
      Map<String, int> tasksByMember = {};
      for (var task in tasks) {
        if (task.assignedTo != null && task.assignedTo!.isNotEmpty) {
          for (var member in task.assignedTo!) {
            tasksByMember[member] = (tasksByMember[member] ?? 0) + 1;
          }
        }
      }
      
      // Phân tích nhiệm vụ theo mức độ ưu tiên
      Map<String, int> tasksByPriority = {};
      for (var task in tasks) {
        tasksByPriority[task.priority] = (tasksByPriority[task.priority] ?? 0) + 1;
      }
      
      // Tạo dữ liệu báo cáo
      final reportData = ProjectStatusReport(
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        inProgressTasks: inProgressTasks,
        pendingTasks: pendingTasks,
        overdueTasks: overdueTasks,
        completionPercentage: completionPercentage,
        tasksByMember: tasksByMember,
        tasksByPriority: tasksByPriority,
        recentActivities: recentActivities,
      );
      
      // Tạo báo cáo
      final report = Report(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        projectId: projectId,
        createdBy: createdBy,
        reportType: 'project_status',
        reportData: reportData.toJson(),
        reportDate: reportDate,
        isShared: false,
        sharedWith: [],
      );
      
      return await createReport(report);
    } catch (e) {
      print('Error generating project status report: $e');
      return null;
    }
  }

  // Tạo báo cáo sử dụng tài nguyên
  Future<String?> generateResourceUsageReport(
    String projectId, 
    String title, 
    String description, 
    String createdBy,
    DateTime reportDate,
    List<Resource> resources,
    List<ResourceAllocation> allocations,
    Map<String, Task> tasks,
  ) async {
    try {
      // Tính tổng chi phí tài nguyên
      double totalResourceCost = 0;
      for (var resource in resources) {
        totalResourceCost += resource.getTotalCost();
      }
      
      // Phân tích chi phí theo loại tài nguyên
      Map<String, double> costByResourceType = {};
      for (var resource in resources) {
        costByResourceType[resource.type] = (costByResourceType[resource.type] ?? 0.0) + resource.getTotalCost();
      }
      
      // Phân tích chi phí theo nhiệm vụ
      Map<String, double> costByTask = {};
      for (var allocation in allocations) {
        // Tìm tài nguyên tương ứng
        final resource = resources.firstWhere(
          (r) => r.id == allocation.resourceId,
          orElse: () => resources.first, // Fallback nếu không tìm thấy
        );
        
        // Tính chi phí phân bổ
        final cost = resource.costPerUnit * allocation.allocatedUnits;
        
        // Cập nhật chi phí theo nhiệm vụ
        costByTask[allocation.taskId] = (costByTask[allocation.taskId] ?? 0.0) + cost;
      }
      
      // Phân tích hiệu suất sử dụng tài nguyên
      List<Map<String, dynamic>> resourceUtilization = [];
      for (var resource in resources) {
        resourceUtilization.add({
          'resourceId': resource.id,
          'resourceName': resource.name,
          'utilizationRate': resource.availableUnits > 0 
              ? (resource.allocatedUnits / resource.availableUnits) * 100 
              : 0.0,
        });
      }
      
      // Tính hiệu quả sử dụng tài nguyên
      Map<String, double> resourceEfficiency = {};
      for (var allocation in allocations) {
        if (!tasks.containsKey(allocation.taskId)) continue;
        
        final task = tasks[allocation.taskId]!;
        if (task.status != 'completed') continue;
        
        // Tìm tài nguyên tương ứng
        final resource = resources.firstWhere(
          (r) => r.id == allocation.resourceId,
          orElse: () => resources.first, // Fallback nếu không tìm thấy
        );
        
        // Tính chi phí phân bổ
        final cost = resource.costPerUnit * allocation.allocatedUnits;
        
        // Đánh giá hiệu quả (giả định: điểm hoàn thành / chi phí)
        final efficiency = task.completionPercentage / (cost > 0 ? cost : 1);
        
        resourceEfficiency[resource.id] = efficiency;
      }
      
      // Tạo dữ liệu báo cáo
      final reportData = ResourceUsageReport(
        totalResourceCost: totalResourceCost,
        costByResourceType: costByResourceType,
        costByTask: costByTask,
        resourceUtilization: resourceUtilization,
        resourceEfficiency: resourceEfficiency,
      );
      
      // Tạo báo cáo
      final report = Report(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        projectId: projectId,
        createdBy: createdBy,
        reportType: 'resource_usage',
        reportData: reportData.toJson(),
        reportDate: reportDate,
        isShared: false,
        sharedWith: [],
      );
      
      return await createReport(report);
    } catch (e) {
      print('Error generating resource usage report: $e');
      return null;
    }
  }

  // Tạo báo cáo ngân sách
  Future<String?> generateBudgetReport(
    String projectId, 
    String title, 
    String description, 
    String createdBy,
    DateTime reportDate,
    Budget budget,
    Map<String, double> spendingTrend,
    List<Map<String, dynamic>> budgetForecast,
  ) async {
    try {
      // Tạo dữ liệu báo cáo
      final reportData = BudgetReport(
        totalBudget: budget.totalBudget,
        allocatedBudget: budget.allocatedBudget,
        spentBudget: budget.spentBudget,
        remainingBudget: budget.getRemainingBudget(),
        spendingByCategory: budget.categoryAllocation,
        spendingTrend: spendingTrend,
        budgetForecast: budgetForecast,
        isOverBudget: budget.spentBudget > budget.totalBudget,
        burnRate: budget.totalBudget > 0 
            ? (budget.spentBudget / budget.totalBudget) * 100 
            : 0.0,
      );
      
      // Tạo báo cáo
      final report = Report(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        projectId: projectId,
        createdBy: createdBy,
        reportType: 'budget',
        reportData: reportData.toJson(),
        reportDate: reportDate,
        isShared: false,
        sharedWith: [],
      );
      
      return await createReport(report);
    } catch (e) {
      print('Error generating budget report: $e');
      return null;
    }
  }

  // Tạo báo cáo hiệu suất
  Future<String?> generatePerformanceReport(
    String projectId, 
    String title, 
    String description, 
    String createdBy,
    DateTime reportDate,
    List<Task> completedTasks,
    Map<String, int> taskCompletionTimes,
    Map<String, double> memberProductivity,
    Map<String, double> memberEfficiency,
    List<Map<String, dynamic>> performanceTrend,
  ) async {
    try {
      // Tính thời gian hoàn thành trung bình
      double averageCompletionTime = 0;
      if (taskCompletionTimes.isNotEmpty) {
        int totalTime = taskCompletionTimes.values.reduce((a, b) => a + b);
        averageCompletionTime = totalTime / taskCompletionTimes.length;
      }
      
      // Tạo gợi ý cải thiện hiệu suất
      List<Map<String, dynamic>> improvementSuggestions = [];
      
      // Phân tích hiệu suất theo thành viên
      for (var entry in memberEfficiency.entries) {
        String memberId = entry.key;
        double efficiency = entry.value;
        
        if (efficiency < 0.7) { // Ngưỡng hiệu suất thấp
          improvementSuggestions.add({
            'memberId': memberId,
            'suggestion': 'Cần đào tạo thêm hoặc hỗ trợ để nâng cao hiệu suất',
            'currentEfficiency': efficiency,
          });
        }
      }
      
      // Phân tích thời gian hoàn thành nhiệm vụ
      for (var task in completedTasks) {
        if (task.completedAt != null && task.startedAt != null) {
          int completionTime = task.completedAt!.difference(task.startedAt!).inHours;
          
          if (completionTime > averageCompletionTime * 1.5) { // Nhiệm vụ mất nhiều thời gian hơn 50% so với trung bình
            improvementSuggestions.add({
              'taskId': task.id,
              'taskName': task.title,
              'suggestion': 'Nhiệm vụ này mất nhiều thời gian hơn dự kiến, cần xem xét lại quy trình',
              'completionTime': completionTime,
              'averageTime': averageCompletionTime,
            });
          }
        }
      }
      
      // Tạo dữ liệu báo cáo
      final reportData = PerformanceReport(
        memberProductivity: memberProductivity,
        taskCompletionTime: taskCompletionTimes,
        averageTaskCompletionTime: averageCompletionTime,
        memberEfficiency: memberEfficiency,
        performanceTrend: performanceTrend,
        improvementSuggestions: improvementSuggestions,
      );
      
      // Tạo báo cáo
      final report = Report(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        projectId: projectId,
        createdBy: createdBy,
        reportType: 'performance',
        reportData: reportData.toJson(),
        reportDate: reportDate,
        isShared: false,
        sharedWith: [],
      );
      
      return await createReport(report);
    } catch (e) {
      print('Error generating performance report: $e');
      return null;
    }
  }
} 