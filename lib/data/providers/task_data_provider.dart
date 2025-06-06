import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/models/task_model.dart';

class TaskDataProvider {
  final SharedPreferences _prefs;
  static const String _tasksKey = 'tasks';
  static const String _syncTimeKey = 'last_sync_time';
  static const String _tasksCacheKey = 'tasks_cache';
  static const int _cacheDurationMinutes = 30;

  TaskDataProvider(this._prefs);

  Future<List<Task>> getTasks() async {
    final String? tasksJson = _prefs.getString(_tasksKey);
    if (tasksJson == null) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(tasksJson);
    return decoded.map((item) => Task.fromJson(item)).toList();
  }

  Future<bool> saveTasks(List<Task> tasks) async {
    final List<Map<String, dynamic>> jsonList = tasks.map((task) => task.toJson()).toList();
    final String encodedTasks = jsonEncode(jsonList);
    return await _prefs.setString(_tasksKey, encodedTasks);
  }
  
  // Lưu thời gian đồng bộ cuối cùng
  Future<bool> saveLastSyncTime(DateTime syncTime) async {
    return await _prefs.setInt(_syncTimeKey, syncTime.millisecondsSinceEpoch);
  }
  
  // Lấy thời gian đồng bộ cuối cùng
  DateTime? getLastSyncTime() {
    final int? timestamp = _prefs.getInt(_syncTimeKey);
    if (timestamp == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  
  // Kiểm tra xem có cần đồng bộ lại không
  bool needsSync() {
    final DateTime? lastSync = getLastSyncTime();
    if (lastSync == null) {
      return true; // Chưa từng đồng bộ
    }
    
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(lastSync);
    return difference.inMinutes > _cacheDurationMinutes; // Đồng bộ lại sau 30 phút
  }
  
  // Lưu cache cho một dự án cụ thể
  Future<bool> saveProjectTasksCache(String projectId, List<Task> tasks) async {
    final Map<String, dynamic> cache = await _getProjectCaches();
    
    // Lưu tasks theo project ID
    final List<Map<String, dynamic>> jsonList = tasks.map((task) => task.toJson()).toList();
    cache[projectId] = {
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': jsonList,
    };
    
    final String encodedCache = jsonEncode(cache);
    return await _prefs.setString(_tasksCacheKey, encodedCache);
  }
  
  // Lấy cache cho một dự án cụ thể
  Future<List<Task>> getCachedTasks(String projectId) async {
    final Map<String, dynamic> allCaches = await _getProjectCaches();
    
    if (!allCaches.containsKey(projectId)) {
      return [];
    }
    
    final Map<String, dynamic> projectCache = allCaches[projectId];
    final DateTime cacheTime = DateTime.parse(projectCache['timestamp']);
    
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(cacheTime);
    if (difference.inMinutes > _cacheDurationMinutes) {
      return []; // Cache đã hết hạn
    }
    
    final List<dynamic> tasksJson = projectCache['tasks'];
    return tasksJson.map((item) => Task.fromJson(item)).toList();
  }
  
  // Lấy tất cả cache của các dự án
  Future<Map<String, dynamic>> _getProjectCaches() async {
    final String? cacheJson = _prefs.getString(_tasksCacheKey);
    if (cacheJson == null) {
      return {};
    }
    
    return jsonDecode(cacheJson);
  }
  
  // Xóa tất cả cache
  Future<bool> clearCache() async {
    return await _prefs.remove(_tasksCacheKey);
  }

  Future<List<Task>> getTasksByProject(String projectId) async {
    final tasksJson = _prefs.getString(_tasksKey) ?? '[]';
    final List<dynamic> tasksList = jsonDecode(tasksJson);
    
    return tasksList
        .map((task) => Task.fromJson(task))
        .where((task) => task.projectId == projectId)
        .toList();
  }
  
  Future<List<String>> getProjectMembers(String projectId) async {
    try {
      print('Getting members for project: $projectId');
      
      // Try Enterprise projects first
      final enterpriseDoc = await FirebaseFirestore.instance
          .collection('EnterpriseProjects')
          .doc(projectId)
          .get();
      
      if (enterpriseDoc.exists && enterpriseDoc.data() != null) {
        final data = enterpriseDoc.data()!;
        print('Enterprise project data: $data');
        
        if (data['memberEmails'] != null && data['memberEmails'] is List) {
          final members = List<String>.from(data['memberEmails']);
          print('Found ${members.length} enterprise members: $members');
          return members;
        }
      }
      
      // Fallback to regular projects
      final regularDoc = await FirebaseFirestore.instance
          .collection('Project')
          .doc(projectId)
          .get();
      
      if (regularDoc.exists && regularDoc.data() != null) {
        final data = regularDoc.data()!;
        print('Regular project data: $data');
        
        if (data['email'] != null && data['email'] is List) {
          final members = List<String>.from(data['email']);
          print('Found ${members.length} regular members: $members');
          return members;
        }
      }
      
      print('No members found in project');
      return [];
    } catch (e) {
      print('Error getting project members: $e');
      return [];
    }
  }
  
  Future<void> createTask(Task task) async {
    final tasksJson = _prefs.getString(_tasksKey) ?? '[]';
    final List<dynamic> tasksList = jsonDecode(tasksJson);
    
    tasksList.add(task.toJson());
    
    await _prefs.setString(_tasksKey, jsonEncode(tasksList));
  }
  
  Future<void> updateTask(Task task) async {
    final tasksJson = _prefs.getString(_tasksKey) ?? '[]';
    final List<dynamic> tasksList = jsonDecode(tasksJson);
    
    final index = tasksList.indexWhere((t) => t['id'] == task.id);
    
    if (index != -1) {
      tasksList[index] = task.toJson();
      await _prefs.setString(_tasksKey, jsonEncode(tasksList));
    }
  }
  
  Future<void> deleteTask(String taskId) async {
    final tasksJson = _prefs.getString(_tasksKey) ?? '[]';
    final List<dynamic> tasksList = jsonDecode(tasksJson);
    
    final filteredList = tasksList.where((task) => task['id'] != taskId).toList();
    
    await _prefs.setString(_tasksKey, jsonEncode(filteredList));
  }
} 