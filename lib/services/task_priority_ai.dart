import 'package:mission_master/data/models/task_model.dart';

class TaskPriorityAI {
  /// Tính toán độ ưu tiên thông minh cho task (0-100)
  static int calculateSmartPriority(Task task, {
    int totalProjectTasks = 10,
    List<String> allProjectMembers = const [],
  }) {
    int score = 0;
    
    // 1. DEADLINE URGENCY (40 điểm)
    final urgencyScore = _calculateUrgencyScore(task.deadlineDate);
    score += (urgencyScore * 0.4).round();
    
    // 2. TASK COMPLEXITY (25 điểm) 
    final complexityScore = _calculateComplexityScore(task);
    score += (complexityScore * 0.25).round();
    
    // 3. MEMBER WORKLOAD (20 điểm)
    final workloadScore = _calculateWorkloadScore(task.members.length, allProjectMembers.length);
    score += (workloadScore * 0.2).round();
    
    // 4. PROJECT IMPORTANCE (15 điểm)
    final importanceScore = _calculateProjectImportance(task.projectName);
    score += (importanceScore * 0.15).round();
    
    return score.clamp(0, 100);
  }
  
  /// Sắp xếp danh sách task theo độ ưu tiên thông minh
  static List<Task> sortTasksBySmartPriority(List<Task> tasks) {
    // Tính toán context cho tất cả tasks
    final allMembers = tasks.expand((t) => t.members).toSet().toList();
    
    // Tính điểm ưu tiên cho từng task
    final tasksWithPriority = tasks.map((task) {
      final priorityScore = calculateSmartPriority(
        task, 
        totalProjectTasks: tasks.length,
        allProjectMembers: allMembers,
      );
      return _TaskWithPriority(task, priorityScore);
    }).toList();
    
    // Sắp xếp theo độ ưu tiên giảm dần
    tasksWithPriority.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    
    return tasksWithPriority.map((twp) => twp.task).toList();
  }
  
  /// Lấy top N task ưu tiên cao nhất
  static List<Task> getTopPriorityTasks(List<Task> tasks, {int limit = 5}) {
    final sortedTasks = sortTasksBySmartPriority(tasks);
    return sortedTasks.take(limit).toList();
  }
  
  /// Tính điểm độ khẩn cấp dựa trên deadline
  static int _calculateUrgencyScore(String deadlineDate) {
    try {
      final parts = deadlineDate.split('/');
      if (parts.length != 3) return 50; // Default if invalid format
      
      final deadline = DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month  
        int.parse(parts[0]), // day
      );
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final daysUntilDeadline = deadline.difference(today).inDays;
      
      if (daysUntilDeadline < 0) return 100; // Quá hạn = ưu tiên cực cao
      if (daysUntilDeadline == 0) return 95; // Hôm nay
      if (daysUntilDeadline == 1) return 85; // Ngày mai
      if (daysUntilDeadline <= 3) return 70; // 2-3 ngày
      if (daysUntilDeadline <= 7) return 50; // 1 tuần
      if (daysUntilDeadline <= 14) return 30; // 2 tuần
      return 20; // > 2 tuần
      
    } catch (e) {
      return 50; // Default nếu có lỗi
    }
  }
  
  /// Tính điểm độ phức tạp dựa trên mô tả và từ khóa
  static int _calculateComplexityScore(Task task) {
    int complexity = 50; // Base score
    
    final description = '${task.title} ${task.description}'.toLowerCase();
    
    // Keywords tăng độ phức tạp
    final complexKeywords = [
      'api', 'database', 'backend', 'integration', 'algorithm',
      'security', 'authentication', 'payment', 'deploy', 'architecture',
      'performance', 'optimization', 'migration', 'refactor'
    ];
    
    // Keywords giảm độ phức tạp  
    final simpleKeywords = [
      'ui', 'design', 'mockup', 'wireframe', 'content', 
      'text', 'image', 'copy', 'update', 'fix typo'
    ];
    
    // Tính điểm dựa trên keywords
    for (String keyword in complexKeywords) {
      if (description.contains(keyword)) complexity += 10;
    }
    
    for (String keyword in simpleKeywords) {
      if (description.contains(keyword)) complexity -= 10;
    }
    
    // Độ dài mô tả cũng ảnh hưởng
    if (description.length > 200) complexity += 15;
    else if (description.length < 50) complexity -= 10;
    
    return complexity.clamp(0, 100);
  }
  
  /// Tính điểm dựa trên số lượng member được assign
  static int _calculateWorkloadScore(int assignedMembers, int totalMembers) {
    if (totalMembers == 0) return 50;
    
    final workloadRatio = assignedMembers / totalMembers;
    
    // Ít member = workload cao = ưu tiên cao
    if (workloadRatio <= 0.2) return 80; // 1-2 người
    if (workloadRatio <= 0.4) return 60; // 3-4 người  
    if (workloadRatio <= 0.6) return 40; // 5-6 người
    return 20; // Nhiều người = ít urgent
  }
  
  /// Tính điểm tầm quan trọng dựa trên tên project
  static int _calculateProjectImportance(String projectName) {
    final name = projectName.toLowerCase();
    
    // Enterprise projects = quan trọng hơn
    if (name.contains('enterprise')) return 80;
    if (name.contains('client') || name.contains('customer')) return 70;
    if (name.contains('production') || name.contains('live')) return 75;
    if (name.contains('test') || name.contains('demo')) return 30;
    
    return 50; // Default
  }
  
  /// Phân loại mức độ ưu tiên
  static String getPriorityLabel(int score) {
    if (score >= 80) return 'Cực cao 🔥';
    if (score >= 65) return 'Cao ⚡';
    if (score >= 45) return 'Trung bình 📋';
    if (score >= 25) return 'Thấp 📝';
    return 'Rất thấp 💤';
  }
  
  /// Màu sắc cho mức độ ưu tiên
  static String getPriorityColor(int score) {
    if (score >= 80) return '#FF4444'; // Đỏ
    if (score >= 65) return '#FF8800'; // Cam
    if (score >= 45) return '#FFBB00'; // Vàng
    if (score >= 25) return '#00AA44'; // Xanh lá
    return '#888888'; // Xám
  }
}

class _TaskWithPriority {
  final Task task;
  final int priorityScore;
  
  _TaskWithPriority(this.task, this.priorityScore);
} 