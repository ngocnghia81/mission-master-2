import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';

class AppTheme {
  // Light theme
  static ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.indigo,
    scaffoldBackgroundColor: Colors.white,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: Colors.indigo,
      secondary: Colors.orange,
    ),
    useMaterial3: true,
    primaryColor: AppColors.primaryColor,
    cardTheme: CardTheme(
      color: AppColors.cardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accentColor,
      foregroundColor: AppColors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: AppColors.black),
      bodyMedium: TextStyle(color: AppColors.black),
      bodySmall: TextStyle(color: AppColors.grey),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.taskPending,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.white,
    ),
  );

  // Dark theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primaryColor,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryColor,
      secondary: AppColors.secondaryColor,
      background: const Color(0xFF121212),
      surface: const Color(0xFF242424),
      onSurface: AppColors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF242424),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accentColor,
      foregroundColor: AppColors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: AppColors.white),
      bodyMedium: TextStyle(color: AppColors.white),
      bodySmall: TextStyle(color: Color(0xFFBBBBBB)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF303030),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF1E1E1E),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3E3E3E),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: AppColors.primaryColor,
      unselectedItemColor: Color(0xFF8E8E8E),
    ),
  );
} 