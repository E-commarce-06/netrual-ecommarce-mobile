import 'package:flutter/material.dart';

/// Shared app palette with safe, validated runtime brand colors.
class AppColors {
  AppColors._();

  static const Color _defaultPrimary = Color(0xFF1268C4);
  static const Color _defaultAccent = Color(0xFF0C62B8);
  static Color _brandPrimary = _defaultPrimary;
  static Color _brandAccent = _defaultAccent;

  static Color get primary => _brandPrimary;
  static Color get accent => _brandAccent;
  static Color get primaryDark => Color.lerp(_brandPrimary, Colors.black, 0.24)!;
  static Color get primaryLight => Color.lerp(_brandPrimary, Colors.white, 0.20)!;
  static List<Color> get primaryGradient => [primary, primaryDark];

  /// Applies store colors only when they are strict six-digit RGB values.
  /// Invalid or missing remote values fall back to the bundled palette.
  static void applyBrandColors({String? primaryHex, String? accentHex}) {
    _brandPrimary = _parseHexColor(primaryHex) ?? _defaultPrimary;
    _brandAccent = _parseHexColor(accentHex) ?? _defaultAccent;
  }

  static Color? _parseHexColor(String? value) {
    if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }
    final color = Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
    return 1.05 / (color.computeLuminance() + 0.05) >= 4.5 ? color : null;
  }

  // Background Colors
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color backgroundDark = Color(0xFF101922);

  // Surface Colors (dark: elevated slate so inputs/cards read clearly on #101922)
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF243447);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Border Colors (dark: visible slate edge on navy surfaces)
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF5A6B7D);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Rating Colors
  static const Color starColor = Color(0xFFFFC107);

  // Dark mode colors
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkDivider = Color(0xFF334155);
}
