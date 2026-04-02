import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('spacing values are increasing', () {
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
    });

    test('radius values are increasing', () {
      expect(AppSpacing.radiusSm, lessThan(AppSpacing.radiusMd));
      expect(AppSpacing.radiusMd, lessThan(AppSpacing.radiusLg));
      expect(AppSpacing.radiusLg, lessThan(AppSpacing.radiusFull));
    });

    test('minTapTarget is at least 48', () {
      expect(AppSpacing.minTapTarget, greaterThanOrEqualTo(48));
    });
  });
}
