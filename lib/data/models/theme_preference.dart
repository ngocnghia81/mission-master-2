import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreference extends ChangeNotifier {
  static const THEME_MODE = "THEME_MODE";
  
  ThemeMode _themeMode = ThemeMode.light;
  SharedPreferences? _preferences;
  
  ThemeMode get themeMode => _themeMode;
  
  ThemePreference() {
    _loadFromPrefs();
  }
  
  // Khởi tạo SharedPreferences
  _initPrefs() async {
    _preferences ??= await SharedPreferences.getInstance();
  }
  
  // Đọc giá trị từ SharedPreferences
  _loadFromPrefs() async {
    await _initPrefs();
    int theme = _preferences?.getInt(THEME_MODE) ?? 0;
    _themeMode = ThemeMode.values[theme];
    notifyListeners();
  }
  
  // Lưu giá trị vào SharedPreferences
  _saveToPrefs() async {
    await _initPrefs();
    int theme = _themeMode.index;
    _preferences?.setInt(THEME_MODE, theme);
  }
  
  // Cập nhật ThemeMode
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveToPrefs();
    notifyListeners();
  }
  
  // Chuyển đổi giữa light và dark mode
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    _saveToPrefs();
    notifyListeners();
  }
} 