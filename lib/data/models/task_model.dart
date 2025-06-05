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
    );
  }
} 