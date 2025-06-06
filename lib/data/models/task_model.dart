import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String deadlineDate;
  final String deadlineTime;
  final List<String> members;
  final String status;
  final String projectName;
  final String projectId;
  final String priority;
  final bool isRecurring;
  final String recurringInterval;
  final DateTime? createdAt;
  final DateTime? lastModified;
  final List<String>? assignedTo;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double completionPercentage;
  final List<String>? dependencies;
  final List<String>? attachments;
  final List<Map<String, dynamic>>? comments;
  final Map<String, dynamic>? metadata;
  final String? assignedBy;
  final List<String>? resourceIds;
  final double? estimatedCost;
  final double? actualCost;
  final int? estimatedHours;
  final int? actualHours;
  final String? category;
  final List<String>? tags;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.deadlineDate,
    required this.deadlineTime,
    required this.members,
    required this.status,
    required this.projectName,
    required this.projectId,
    this.priority = 'normal',
    this.isRecurring = false,
    this.recurringInterval = '',
    this.createdAt,
    this.lastModified,
    this.assignedTo,
    this.dueDate,
    this.startedAt,
    this.completedAt,
    this.completionPercentage = 0.0,
    this.dependencies,
    this.attachments,
    this.comments,
    this.metadata,
    this.assignedBy,
    this.resourceIds,
    this.estimatedCost,
    this.actualCost,
    this.estimatedHours,
    this.actualHours,
    this.category,
    this.tags,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['taskName'] as String,
      description: json['description'] as String,
      deadlineDate: json['deadlineDate'] as String,
      deadlineTime: json['deadlineTime'] as String,
      members: List<String>.from(json['Members']),
      status: json['status'] as String,
      projectName: json['projectName'] as String,
      projectId: json['projectId'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringInterval: json['recurringInterval'] as String? ?? '',
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['createdAt'])) 
          : null,
      lastModified: json['lastModified'] != null 
          ? (json['lastModified'] is Timestamp 
              ? (json['lastModified'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['lastModified'])) 
          : null,
      assignedTo: json['assignedTo'] != null ? List<String>.from(json['assignedTo']) : null,
      dueDate: json['dueDate'] != null 
          ? (json['dueDate'] is Timestamp 
              ? (json['dueDate'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['dueDate'])) 
          : null,
      startedAt: json['startedAt'] != null 
          ? (json['startedAt'] is Timestamp 
              ? (json['startedAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['startedAt'])) 
          : null,
      completedAt: json['completedAt'] != null 
          ? (json['completedAt'] is Timestamp 
              ? (json['completedAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(json['completedAt'])) 
          : null,
      completionPercentage: json['completionPercentage'] != null 
          ? (json['completionPercentage'] as num).toDouble() 
          : 0.0,
      dependencies: json['dependencies'] != null ? List<String>.from(json['dependencies']) : null,
      attachments: json['attachments'] != null ? List<String>.from(json['attachments']) : null,
      comments: json['comments'] != null 
          ? List<Map<String, dynamic>>.from(json['comments']) 
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      assignedBy: json['assignedBy'] as String?,
      resourceIds: json['resourceIds'] != null ? List<String>.from(json['resourceIds']) : null,
      estimatedCost: json['estimatedCost'] != null ? (json['estimatedCost'] as num).toDouble() : null,
      actualCost: json['actualCost'] != null ? (json['actualCost'] as num).toDouble() : null,
      estimatedHours: json['estimatedHours'] as int?,
      actualHours: json['actualHours'] as int?,
      category: json['category'] as String?,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskName': title,
      'description': description,
      'deadlineDate': deadlineDate,
      'deadlineTime': deadlineTime,
      'Members': members,
      'status': status,
      'projectName': projectName,
      'projectId': projectId,
      'priority': priority,
      'isRecurring': isRecurring,
      'recurringInterval': recurringInterval,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'lastModified': lastModified?.millisecondsSinceEpoch,
      'assignedTo': assignedTo,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'completionPercentage': completionPercentage,
      'dependencies': dependencies,
      'attachments': attachments,
      'comments': comments,
      'metadata': metadata,
      'assignedBy': assignedBy,
      'resourceIds': resourceIds,
      'estimatedCost': estimatedCost,
      'actualCost': actualCost,
      'estimatedHours': estimatedHours,
      'actualHours': actualHours,
      'category': category,
      'tags': tags,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? deadlineDate,
    String? deadlineTime,
    List<String>? members,
    String? status,
    String? projectName,
    String? projectId,
    String? priority,
    bool? isRecurring,
    String? recurringInterval,
    DateTime? createdAt,
    DateTime? lastModified,
    List<String>? assignedTo,
    DateTime? dueDate,
    DateTime? startedAt,
    DateTime? completedAt,
    double? completionPercentage,
    List<String>? dependencies,
    List<String>? attachments,
    List<Map<String, dynamic>>? comments,
    Map<String, dynamic>? metadata,
    String? assignedBy,
    List<String>? resourceIds,
    double? estimatedCost,
    double? actualCost,
    int? estimatedHours,
    int? actualHours,
    String? category,
    List<String>? tags,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      deadlineTime: deadlineTime ?? this.deadlineTime,
      members: members ?? this.members,
      status: status ?? this.status,
      projectName: projectName ?? this.projectName,
      projectId: projectId ?? this.projectId,
      priority: priority ?? this.priority,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      dependencies: dependencies ?? this.dependencies,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
      metadata: metadata ?? this.metadata,
      assignedBy: assignedBy ?? this.assignedBy,
      resourceIds: resourceIds ?? this.resourceIds,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }
} 