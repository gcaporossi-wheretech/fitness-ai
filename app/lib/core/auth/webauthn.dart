/// Cross-platform WebAuthn facade.
///
/// On web it binds to `web/webauthn.js` via dart:js_interop; on other platforms
/// it falls back to a stub that reports unsupported.
export 'webauthn_stub.dart' if (dart.library.js_interop) 'webauthn_web.dart';
