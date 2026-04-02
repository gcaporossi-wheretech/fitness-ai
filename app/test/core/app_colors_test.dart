import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('bgPrimary is dark black', () {
      expect(AppColors.bgPrimary, const Color(0xFF0D0D0D));
    });

    test('primary is blue', () {
      expect(AppColors.primary, const Color(0xFF4F8CFF));
    });

    test('success is teal green', () {
      expect(AppColors.success, const Color(0xFF00D4AA));
    });

    test('error is red', () {
      expect(AppColors.error, const Color(0xFFFF4757));
    });

    test('heroGradient goes from primary to success', () {
      expect(AppColors.heroGradient.colors, [
        AppColors.primary,
        AppColors.success,
      ]);
    });

    test('textPrimary is white', () {
      expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
    });
  });
}
