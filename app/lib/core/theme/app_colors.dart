import 'package:flutter/material.dart';

/// Design system colors for FitnessAI.
/// Dark mode premium palette inherited from GymTracker prototype.
class AppColors {
  AppColors._();

  // Backgrounds
  static const bgPrimary = Color(0xFF0D0D0D);
  static const bgSecondary = Color(0xFF1A1A2E);
  static const bgElevated = Color(0xFF16213E);
  static const bgOverlay = Color(0xFF1E1E3A);

  // Accent
  static const primary = Color(0xFF4F8CFF);
  static const primaryGlow = Color(0x334F8CFF);
  static const success = Color(0xFF00D4AA);
  static const successGlow = Color(0x3300D4AA);
  static const warning = Color(0xFFFFB800);
  static const error = Color(0xFFFF4757);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8B8B9E);
  static const textDisabled = Color(0xFF4A4A5A);

  // Gradients
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, success],
  );

  static const warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), warning],
  );

  static const darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgSecondary, bgPrimary],
  );
}
