import 'package:cloud_firestore/cloud_firestore.dart';

class Resource {
  final String id;
  final String name;
  final String description;
  final String type; // human, material, equipment, etc.
  final double costPerUnit;
  final String costUnit; // hour, day, piece, etc.
  final int availableUnits;
  final int allocatedUnits;
  final String projectId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Resource({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.costPerUnit,
    required this.costUnit,
    required this.availableUnits,
    required this.allocatedUnits,
    required this.projectId,
    this.createdAt,
    this.updatedAt,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      costPerUnit: (json['costPerUnit'] as num).toDouble(),
      costUnit: json['costUnit'] as String,
      availableUnits: json['availableUnits'] as int,
      allocatedUnits: json['allocatedUnits'] as int,
      projectId: json['projectId'] as String,
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
      'name': name,
      'description': description,
      'type': type,
      'costPerUnit': costPerUnit,
      'costUnit': costUnit,
      'availableUnits': availableUnits,
      'allocatedUnits': allocatedUnits,
      'projectId': projectId,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  Resource copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    double? costPerUnit,
    String? costUnit,
    int? availableUnits,
    int? allocatedUnits,
    String? projectId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Resource(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      costUnit: costUnit ?? this.costUnit,
      availableUnits: availableUnits ?? this.availableUnits,
      allocatedUnits: allocatedUnits ?? this.allocatedUnits,
      projectId: projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  // Tính tổng chi phí của tài nguyên
  double getTotalCost() {
    return costPerUnit * allocatedUnits;
  }
  
  // Kiểm tra xem tài nguyên có sẵn sàng để phân bổ thêm không
  bool canAllocateMore(int units) {
    return (allocatedUnits + units) <= availableUnits;
  }
}

class ResourceAllocation {
  final String id;
  final String resourceId;
  final String taskId;
  final String projectId;
  final int allocatedUnits;
  final DateTime startDate;
  final DateTime endDate;
  final String allocatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ResourceAllocation({
    required this.id,
    required this.resourceId,
    required this.taskId,
    required this.projectId,
    required this.allocatedUnits,
    required this.startDate,
    required this.endDate,
    required this.allocatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ResourceAllocation.fromJson(Map<String, dynamic> json) {
    return ResourceAllocation(
      id: json['id'] as String,
      resourceId: json['resourceId'] as String,
      taskId: json['taskId'] as String,
      projectId: json['projectId'] as String,
      allocatedUnits: json['allocatedUnits'] as int,
      startDate: json['startDate'] is Timestamp 
          ? (json['startDate'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(json['startDate']),
      endDate: json['endDate'] is Timestamp 
          ? (json['endDate'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(json['endDate']),
      allocatedBy: json['allocatedBy'] as String,
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
      'resourceId': resourceId,
      'taskId': taskId,
      'projectId': projectId,
      'allocatedUnits': allocatedUnits,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'allocatedBy': allocatedBy,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

class Budget {
  final String id;
  final String projectId;
  final double totalBudget;
  final double allocatedBudget;
  final double spentBudget;
  final String currency;
  final Map<String, double> categoryAllocation; // e.g. {"human": 5000, "equipment": 2000}
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Budget({
    required this.id,
    required this.projectId,
    required this.totalBudget,
    required this.allocatedBudget,
    required this.spentBudget,
    required this.currency,
    required this.categoryAllocation,
    this.createdAt,
    this.updatedAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      totalBudget: (json['totalBudget'] as num).toDouble(),
      allocatedBudget: (json['allocatedBudget'] as num).toDouble(),
      spentBudget: (json['spentBudget'] as num).toDouble(),
      currency: json['currency'] as String,
      categoryAllocation: Map<String, double>.from(json['categoryAllocation'] ?? {}),
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
      'projectId': projectId,
      'totalBudget': totalBudget,
      'allocatedBudget': allocatedBudget,
      'spentBudget': spentBudget,
      'currency': currency,
      'categoryAllocation': categoryAllocation,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
  
  // Tính ngân sách còn lại
  double getRemainingBudget() {
    return totalBudget - spentBudget;
  }
  
  // Tính phần trăm đã sử dụng
  double getSpentPercentage() {
    if (totalBudget == 0) return 0;
    return (spentBudget / totalBudget) * 100;
  }
  
  // Kiểm tra xem có đủ ngân sách cho một khoản chi tiêu mới không
  bool canSpend(double amount) {
    return (spentBudget + amount) <= totalBudget;
  }
  
  // Copy constructor
  Budget copyWith({
    String? id,
    String? projectId,
    double? totalBudget,
    double? allocatedBudget,
    double? spentBudget,
    String? currency,
    Map<String, double>? categoryAllocation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      totalBudget: totalBudget ?? this.totalBudget,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      spentBudget: spentBudget ?? this.spentBudget,
      currency: currency ?? this.currency,
      categoryAllocation: categoryAllocation ?? this.categoryAllocation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  // Tạo ngân sách mặc định cho một dự án mới
  static Budget createDefault(String projectId) {
    return Budget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      projectId: projectId,
      totalBudget: 0,
      allocatedBudget: 0,
      spentBudget: 0,
      currency: 'VND',
      categoryAllocation: {
        'human': 0,
        'equipment': 0,
        'material': 0,
        'other': 0,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class BudgetItem {
  final String id;
  final String projectId;
  final String category;
  final String title;
  final String description;
  final double allocatedAmount;
  final double spentAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetItem({
    required this.id,
    required this.projectId,
    required this.category,
    required this.title,
    required this.description,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'category': category,
      'title': title,
      'description': description,
      'allocatedAmount': allocatedAmount,
      'spentAmount': spentAmount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'],
      projectId: json['projectId'],
      category: json['category'],
      title: json['title'],
      description: json['description'],
      allocatedAmount: (json['allocatedAmount'] as num).toDouble(),
      spentAmount: (json['spentAmount'] as num).toDouble(),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      return DateTime.now();
    }
  }
  
  BudgetItem copyWith({
    String? id,
    String? projectId,
    String? category,
    String? title,
    String? description,
    double? allocatedAmount,
    double? spentAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}