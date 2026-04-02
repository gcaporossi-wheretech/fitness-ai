import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/constants/api_constants.dart';

void main() {
  group('ApiConstants', () {
    test('auth endpoints start with /auth', () {
      expect(ApiConstants.authLogin, startsWith('/auth'));
      expect(ApiConstants.authRegister, startsWith('/auth'));
      expect(ApiConstants.authRefresh, startsWith('/auth'));
      expect(ApiConstants.authMe, startsWith('/auth'));
    });

    test('workout endpoints start with /workouts', () {
      expect(ApiConstants.workoutPlans, startsWith('/workouts'));
      expect(ApiConstants.workoutSessions, startsWith('/workouts'));
      expect(ApiConstants.workoutSync, startsWith('/workouts'));
      expect(ApiConstants.workoutExercises, startsWith('/workouts'));
    });

    test('ai endpoints start with /ai', () {
      expect(ApiConstants.aiVisionScan, startsWith('/ai'));
      expect(ApiConstants.aiCoachGenerate, startsWith('/ai'));
    });

    test('analytics endpoints start with /analytics', () {
      expect(ApiConstants.analyticsProgress, startsWith('/analytics'));
      expect(ApiConstants.analyticsVolume, startsWith('/analytics'));
    });

    test('timeouts are reasonable', () {
      expect(
        ApiConstants.connectTimeout.inSeconds,
        greaterThanOrEqualTo(5),
      );
      expect(
        ApiConstants.receiveTimeout.inSeconds,
        greaterThanOrEqualTo(10),
      );
    });
  });
}
