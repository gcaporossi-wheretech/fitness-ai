import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web implementation: plays beep sounds and vibrates when timer events occur.
/// Uses dart:js_interop directly (no package:web dependency).
class TimerNotification {
  static JSObject? _audioCtx;

  /// Must be called once from a user gesture (tap) to unlock audio on iOS.
  static void unlockAudio() {
    try {
      _audioCtx ??= _newAudioContext();
      _audioCtx!.callMethod('resume'.toJS);
    } catch (_) {}
  }

  /// Play a short beep sequence and vibrate (timer finished).
  static void notify() {
    _playBeep();
    _vibrate();
  }

  /// Play a short tick sound for countdown (last 5 seconds).
  static void tick() {
    try {
      final ctx = _audioCtx ?? _newAudioContext();
      _audioCtx = ctx;

      final now =
          (ctx.getProperty('currentTime'.toJS) as JSNumber).toDartDouble;
      final osc = ctx.callMethod('createOscillator'.toJS) as JSObject;
      final gain = ctx.callMethod('createGain'.toJS) as JSObject;
      osc.callMethod('connect'.toJS, gain);
      gain.callMethod('connect'.toJS, ctx.getProperty('destination'.toJS));
      final freq = osc.getProperty('frequency'.toJS) as JSObject;
      freq.setProperty('value'.toJS, (660.0).toJS);
      final gainParam = gain.getProperty('gain'.toJS) as JSObject;
      gainParam.setProperty('value'.toJS, (0.25).toJS);
      osc.callMethod('start'.toJS, now.toJS);
      osc.callMethod('stop'.toJS, (now + 0.08).toJS);
    } catch (_) {}
  }

  static JSObject _newAudioContext() {
    return globalContext.callMethod(
      'eval'.toJS,
      'new (window.AudioContext || window.webkitAudioContext)()'.toJS,
    ) as JSObject;
  }

  static void _playBeep() {
    try {
      final ctx = _audioCtx ?? _newAudioContext();
      _audioCtx = ctx;

      final now =
          (ctx.getProperty('currentTime'.toJS) as JSNumber).toDartDouble;
      for (var i = 0; i < 3; i++) {
        final osc = ctx.callMethod('createOscillator'.toJS) as JSObject;
        final gain = ctx.callMethod('createGain'.toJS) as JSObject;
        osc.callMethod('connect'.toJS, gain);
        gain.callMethod('connect'.toJS, ctx.getProperty('destination'.toJS));
        final freq = osc.getProperty('frequency'.toJS) as JSObject;
        freq.setProperty('value'.toJS, (880.0).toJS);
        final gainParam = gain.getProperty('gain'.toJS) as JSObject;
        gainParam.setProperty('value'.toJS, (0.4).toJS);
        osc.callMethod('start'.toJS, (now + i * 0.25).toJS);
        osc.callMethod('stop'.toJS, (now + i * 0.25 + 0.15).toJS);
      }
    } catch (_) {
      // Audio not available - fail silently
    }
  }

  static void _vibrate() {
    try {
      final nav = globalContext.getProperty('navigator'.toJS) as JSObject;
      nav.callMethod('vibrate'.toJS, (200).toJS);
    } catch (_) {
      // Vibration not supported - fail silently
    }
  }
}
