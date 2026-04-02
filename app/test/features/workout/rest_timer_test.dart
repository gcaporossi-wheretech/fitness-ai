import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/services/rest_timer_service.dart';

void main() {
  group('RestTimerService', () {
    late RestTimerService timer;

    setUp(() {
      timer = RestTimerService();
    });

    tearDown(() {
      timer.dispose();
    });

    test('initial state is not running', () {
      expect(timer.isRunning, false);
      expect(timer.remainingSeconds, 0);
      expect(timer.totalSeconds, 0);
    });

    test('start sets running state', () {
      timer.start(90);
      expect(timer.isRunning, true);
      expect(timer.totalSeconds, 90);
      expect(timer.remainingSeconds, greaterThan(0));
    });

    test('formattedTime formats correctly', () {
      timer.start(90);
      expect(timer.formattedTime, matches(RegExp(r'\d{2}:\d{2}')));
    });

    test('progress starts near 0', () {
      timer.start(90);
      expect(timer.progress, lessThan(0.05));
    });

    test('skip stops the timer', () {
      timer.start(90);
      timer.skip();
      expect(timer.isRunning, false);
      expect(timer.remainingSeconds, 0);
    });

    test('stop resets the timer', () {
      timer.start(90);
      timer.stop();
      expect(timer.isRunning, false);
      expect(timer.totalSeconds, 0);
    });

    test('addThirtySeconds increases total', () {
      timer.start(60);
      timer.addThirtySeconds();
      expect(timer.totalSeconds, 90);
    });
  });
}
