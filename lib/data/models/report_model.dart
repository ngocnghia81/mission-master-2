import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String title;
  final String description;
  final String projectId;
  final String createdBy;
  final String reportType; // project_status, resource_usage, budget, performance
  final Map<String, dynamic> reportData;
  final DateTime reportDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isShared;
  final List<String> sharedWith;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Report({
    required this.id,
    required this.title,
    required this.description,
    required this.projectId,
    required this.createdBy,
    required this.reportType,
    required this.reportData,
    required this.reportDate,
    this.startDate,
    this.endDate,
    required this.isShared,
    required this.sharedWith,
    this.createdAt,
    this.updatedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      projectId: json['projectId'] as String,
      createdBy: json['createdBy'] as String,
      reportType: json['reportType'] as String,
      reportData: Map<String, dynamic>.from(json['reportData'] ?? {}),
      reportDate: json['reportDate'] is Timestamp 
          ? (json['reportDate'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(json['reportDate']),
      startDate: json['startDate'] != null 
          ? (json['startDate'] is Timestamp 
              ? (json['startDate'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['startDate']))
          : null,
      endDate: json['endDate'] != null 
          ? (json['endDate'] is Timestamp 
              ? (json['endDate'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['endDate']))
          : null,
      isShared: json['isShared'] as bool? ?? false,
      sharedWith: List<String>.from(json['sharedWith'] ?? []),
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
      'title': title,
      'description': description,
      'projectId': projectId,
      'createdBy': createdBy,
      'reportType': reportType,
      'reportData': reportData,
      'reportDate': reportDate.millisecondsSinceEpoch,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'isShared': isShared,
      'sharedWith': sharedWith,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

class ProjectStatusReport {
  final int totalTasks;
  final int completedTasks;
  final int inProgressTasks;
  final int pendingTasks;
  final int overdueTasks;
  final double completionPercentage;
  final Map<String, int> tasksByMember;
  final Map<String, int> tasksByPriority;
  final List<Map<String, dynamic>> recentActivities;

  ProjectStatusReport({
    required this.totalTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.completionPercentage,
    required this.tasksByMember,
    required this.tasksByPriority,
    required this.recentActivities,
  });

  factory ProjectStatusReport.fromJson(Map<String, dynamic> json) {
    return ProjectStatusReport(
      totalTasks: json['totalTasks'] as int,
      completedTasks: json['completedTasks'] as int,
      inProgressTasks: json['inProgressTasks'] as int,
      pendingTasks: json['pendingTasks'] as int,
      overdueTasks: json['overdueTasks'] as int,
      completionPercentage: (json['completionPercentage'] as num).toDouble(),
      tasksByMember: Map<String, int>.from(json['tasksByMember'] ?? {}),
      tasksByPriority: Map<String, int>.from(json['tasksByPriority'] ?? {}),
      recentActivities: List<Map<String, dynamic>>.from(json['recentActivities'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'inProgressTasks': inProgressTasks,
      'pendingTasks': pendingTasks,
      'overdueTasks': overdueTasks,
      'completionPercentage': completionPercentage,
      'tasksByMember': tasksByMember,
      'tasksByPriority': tasksByPriority,
      'recentActivities': recentActivities,
    };
  }
}

class ResourceUsageReport {
  final double totalResourceCost;
  final Map<String, double> costByResourceType;
  final Map<String, double> costByTask;
  final List<Map<String, dynamic>> resourceUtilization;
  final Map<String, double> resourceEfficiency;

  ResourceUsageReport({
    required this.totalResourceCost,
    required this.costByResourceType,
    required this.costByTask,
    required this.resourceUtilization,
    required this.resourceEfficiency,
  });

  factory ResourceUsageReport.fromJson(Map<String, dynamic> json) {
    return ResourceUsageReport(
      totalResourceCost: (json['totalResourceCost'] as num).toDouble(),
      costByResourceType: Map<String, double>.from(json['costByResourceType'] ?? {}),
      costByTask: Map<String, double>.from(json['costByTask'] ?? {}),
      resourceUtilization: List<Map<String, dynamic>>.from(json['resourceUtilization'] ?? []),
      resourceEfficiency: Map<String, double>.from(json['resourceEfficiency'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalResourceCost': totalResourceCost,
      'costByResourceType': costByResourceType,
      'costByTask': costByTask,
      'resourceUtilization': resourceUtilization,
      'resourceEfficiency': resourceEfficiency,
    };
  }
}

class BudgetReport {
  final double totalBudget;
  final double allocatedBudget;
  final double spentBudget;
  final double remainingBudget;
  final Map<String, double> spendingByCategory;
  final Map<String, double> spendingTrend;
  final List<Map<String, dynamic>> budgetForecast;
  final bool isOverBudget;
  final double burnRate;

  BudgetReport({
    required this.totalBudget,
    required this.allocatedBudget,
    required this.spentBudget,
    required this.remainingBudget,
    required this.spendingByCategory,
    required this.spendingTrend,
    required this.budgetForecast,
    required this.isOverBudget,
    required this.burnRate,
  });

  factory BudgetReport.fromJson(Map<String, dynamic> json) {
    return BudgetReport(
      totalBudget: (json['totalBudget'] as num).toDouble(),
      allocatedBudget: (json['allocatedBudget'] as num).toDouble(),
      spentBudget: (json['spentBudget'] as num).toDouble(),
      remainingBudget: (json['remainingBudget'] as num).toDouble(),
      spendingByCategory: Map<String, double>.from(json['spendingByCategory'] ?? {}),
      spendingTrend: Map<String, double>.from(json['spendingTrend'] ?? {}),
      budgetForecast: List<Map<String, dynamic>>.from(json['budgetForecast'] ?? []),
      isOverBudget: json['isOverBudget'] as bool? ?? false,
      burnRate: (json['burnRate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBudget': totalBudget,
      'allocatedBudget': allocatedBudget,
      'spentBudget': spentBudget,
      'remainingBudget': remainingBudget,
      'spendingByCategory': spendingByCategory,
      'spendingTrend': spendingTrend,
      'budgetForecast': budgetForecast,
      'isOverBudget': isOverBudget,
      'burnRate': burnRate,
    };
  }
}

class PerformanceReport {
  final Map<String, double> memberProductivity;
  final Map<String, int> taskCompletionTime;
  final double averageTaskCompletionTime;
  final Map<String, double> memberEfficiency;
  final List<Map<String, dynamic>> performanceTrend;
  final List<Map<String, dynamic>> improvementSuggestions;

  PerformanceReport({
    required this.memberProductivity,
    required this.taskCompletionTime,
    required this.averageTaskCompletionTime,
    required this.memberEfficiency,
    required this.performanceTrend,
    required this.improvementSuggestions,
  });

  factory PerformanceReport.fromJson(Map<String, dynamic> json) {
    return PerformanceReport(
      memberProductivity: Map<String, double>.from(json['memberProductivity'] ?? {}),
      taskCompletionTime: Map<String, int>.from(json['taskCompletionTime'] ?? {}),
      averageTaskCompletionTime: (json['averageTaskCompletionTime'] as num).toDouble(),
      memberEfficiency: Map<String, double>.from(json['memberEfficiency'] ?? {}),
      performanceTrend: List<Map<String, dynamic>>.from(json['performanceTrend'] ?? []),
      improvementSuggestions: List<Map<String, dynamic>>.from(json['improvementSuggestions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberProductivity': memberProductivity,
      'taskCompletionTime': taskCompletionTime,
      'averageTaskCompletionTime': averageTaskCompletionTime,
      'memberEfficiency': memberEfficiency,
      'performanceTrend': performanceTrend,
      'improvementSuggestions': improvementSuggestions,
    };
  }
} 