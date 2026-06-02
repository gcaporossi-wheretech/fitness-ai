import 'dart:convert';
import 'dart:js_interop';

@JS('fitnessWebAuthnSupported')
external JSBoolean _supported();

@JS('fitnessWebAuthnRegister')
external JSPromise<JSString> _register(JSString optionsJson);

@JS('fitnessWebAuthnAuthenticate')
external JSPromise<JSString> _authenticate(JSString optionsJson);

/// Whether the browser exposes a usable WebAuthn platform authenticator.
bool webauthnSupported() {
  try {
    return _supported().toDart;
  } catch (_) {
    return false;
  }
}

/// Run the registration ceremony (creates a passkey bound to the device).
/// [options] must contain: challenge, rp_id, rp_name, user_id, user_name.
/// Returns: { credential_id, public_key }.
Future<Map<String, dynamic>> webauthnRegister(Map<String, dynamic> options) async {
  final res = await _register(jsonEncode(options).toJS).toDart;
  return jsonDecode(res.toDart) as Map<String, dynamic>;
}

/// Run the authentication ceremony (Face ID / biometric unlock).
/// [options] must contain: rp_id, credential_id.
/// Returns: { credential_id, authenticator_data, client_data_json, signature }.
Future<Map<String, dynamic>> webauthnAuthenticate(Map<String, dynamic> options) async {
  final res = await _authenticate(jsonEncode(options).toJS).toDart;
  return jsonDecode(res.toDart) as Map<String, dynamic>;
}
