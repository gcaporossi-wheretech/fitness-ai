/// Platform-agnostic timer notification.
/// On non-web platforms this is a no-op. The web implementation
/// in `timer_notification_web.dart` plays beep sounds and vibrates.
class TimerNotification {
  /// Must be called once from a user gesture to unlock audio (iOS Safari).
  static void unlockAudio() {}

  /// Play a completion beep sequence and vibrate.
  static void notify() {}

  /// Play a short tick sound for countdown (last 5 seconds).
  static void tick() {}
}
