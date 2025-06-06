class EnterpriseProject {
  final String id;
  final String name;
  final String description;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final List<String> memberEmails;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final bool isEnterprise;
  final Map<String, dynamic> metadata;

  EnterpriseProject({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.memberEmails,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.isEnterprise = true,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'budget': budget,
      'memberEmails': memberEmails,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'isEnterprise': isEnterprise,
      'metadata': metadata,
    };
  }

  factory EnterpriseProject.fromMap(Map<String, dynamic> map) {
    return EnterpriseProject(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'standard',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      budget: (map['budget'] ?? 0.0).toDouble(),
      memberEmails: List<String>.from(map['memberEmails'] ?? []),
      status: map['status'] ?? 'planning',
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      isEnterprise: map['isEnterprise'] ?? true,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  EnterpriseProject copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    List<String>? memberEmails,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    bool? isEnterprise,
    Map<String, dynamic>? metadata,
  }) {
    return EnterpriseProject(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      memberEmails: memberEmails ?? this.memberEmails,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isEnterprise: isEnterprise ?? this.isEnterprise,
      metadata: metadata ?? this.metadata,
    );
  }

  int get durationInDays => endDate.difference(startDate).inDays;
  
  bool get isOverdue => DateTime.now().isAfter(endDate) && status != 'completed';
  
  double get progressPercentage {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0.0;
    if (now.isAfter(endDate)) return 100.0;
    
    final totalDuration = endDate.difference(startDate).inDays;
    final elapsedDuration = now.difference(startDate).inDays;
    
    return (elapsedDuration / totalDuration * 100).clamp(0.0, 100.0);
  }

  String get statusLabel {
    switch (status) {
      case 'planning': return 'Lập kế hoạch';
      case 'active': return 'Đang thực hiện';
      case 'on_hold': return 'Tạm dừng';
      case 'completed': return 'Hoàn thành';
      case 'cancelled': return 'Đã hủy';
      default: return status;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'standard': return 'Tiêu chuẩn';
      case 'agile': return 'Agile';
      case 'waterfall': return 'Waterfall';
      case 'kanban': return 'Kanban';
      case 'scrum': return 'Scrum';
      default: return type;
    }
  }
}

enum ProjectStatus {
  planning('planning', 'Lập kế hoạch'),
  active('active', 'Đang thực hiện'),
  onHold('on_hold', 'Tạm dừng'),
  completed('completed', 'Hoàn thành'),
  cancelled('cancelled', 'Đã hủy');

  const ProjectStatus(this.value, this.label);
  final String value;
  final String label;
}

enum ProjectType {
  standard('standard', 'Tiêu chuẩn'),
  agile('agile', 'Agile'),
  waterfall('waterfall', 'Waterfall'),
  kanban('kanban', 'Kanban'),
  scrum('scrum', 'Scrum');

  const ProjectType(this.value, this.label);
  final String value;
  final String label;
}
