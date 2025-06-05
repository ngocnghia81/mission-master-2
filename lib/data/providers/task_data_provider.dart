import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mission_master/data/models/task_model.dart';

class TaskDataProvider {
  final SharedPreferences _preferences;
  static const String _tasksKey = 'tasks';

  TaskDataProvider(this._preferences);

  Future<List<Task>> getTasks() async {
    final String? tasksJson = _preferences.getString(_tasksKey);
    if (tasksJson == null) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(tasksJson);
    return decoded.map((item) => Task.fromJson(item)).toList();
  }

  Future<bool> saveTasks(List<Task> tasks) async {
    final List<Map<String, dynamic>> jsonList = tasks.map((task) => task.toJson()).toList();
    final String encodedTasks = jsonEncode(jsonList);
    return await _preferences.setString(_tasksKey, encodedTasks);
  }
} 