import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Sports theme
  static const Color primary = Color(0xFF2E7D32); // Green for sports
  static const Color primaryLight = Color(0xFF66BB6A);
  static const Color primaryDark = Color(0xFF1B5E20);
  
  // Status Colors
  static const Color confirmed = Color(0xFF4CAF50); // Green - I'm In
  static const Color declined = Color(0xFFE53935); // Red - I'm Out  
  static const Color maybe = Color(0xFFFF9800); // Orange - Maybe
  static const Color noResponse = Color(0xFF9E9E9E); // Gray - No Response
  
  // UI Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFFBDBDBD);
  
  // Button Colors
  static const Color buttonPrimary = primary;
  static const Color buttonSecondary = Color(0xFF6C757D);
  
  // Status Background Colors (lighter versions)
  static const Color confirmedLight = Color(0xFFE8F5E8);
  static const Color declinedLight = Color(0xFFFFEBEE);
  static const Color maybeLight = Color(0xFFFFF3E0);
  static const Color noResponseLight = Color(0xFFF5F5F5);
  
  // Error and Success
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
}
