import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for JWT tokens.
///
/// Uses flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences
/// on Android). On web, secure-storage reads are unreliable, so we keep an
/// in-memory copy of the tokens for the current session and treat persistent
/// storage as best-effort (wrapped in try/catch). This guarantees the access
/// token is available to the auth interceptor immediately after login on every
/// platform, while still surviving app restarts where storage works.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'fitness_ai_access_token';
  static const _refreshTokenKey = 'fitness_ai_refresh_token';

  // In-memory session cache (shared across instances).
  static String? _accessMem;
  static String? _refreshMem;

  /// Read the stored access token (memory first, then persistent storage).
  Future<String?> getAccessToken() async {
    if (_accessMem != null) return _accessMem;
    try {
      _accessMem = await _storage.read(key: _accessTokenKey);
    } catch (_) {
      _accessMem = null;
    }
    return _accessMem;
  }

  /// Read the stored refresh token (memory first, then persistent storage).
  Future<String?> getRefreshToken() async {
    if (_refreshMem != null) return _refreshMem;
    try {
      _refreshMem = await _storage.read(key: _refreshTokenKey);
    } catch (_) {
      _refreshMem = null;
    }
    return _refreshMem;
  }

  /// Save both tokens after login/register/refresh.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Memory first so it is immediately usable this session.
    _accessMem = accessToken;
    _refreshMem = refreshToken;
    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);
    } catch (_) {
      // Persistent storage is best-effort (notably on web).
    }
  }

  /// Clear all tokens on logout.
  Future<void> clearTokens() async {
    _accessMem = null;
    _refreshMem = null;
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } catch (_) {}
  }

  /// Check whether a user session exists.
  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

/// Provider for token storage singleton.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});
