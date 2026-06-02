import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/services/timer_notification.dart';

void main() {
  group('TimerNotification (default/non-web)', () {
    test('unlockAudio does not throw', () {
      expect(() => TimerNotification.unlockAudio(), returnsNormally);
    });

    test('notify does not throw', () {
      expect(() => TimerNotification.notify(), returnsNormally);
    });

    test('tick does not throw', () {
      expect(() => TimerNotification.tick(), returnsNormally);
    });
  });
}
