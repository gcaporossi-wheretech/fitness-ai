import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:fitness_ai/core/storage/hive_storage.dart';

/// Secure storage for JWT tokens.
///
/// Uses flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences
/// on Android). On WEB, secure-storage is unreliable and effectively in-memory,
/// so tokens were lost whenever the PWA was reloaded/evicted (iOS killing the
/// tab during cardio), logging the user out. To fix that we also persist tokens
/// in the Hive `user` box (IndexedDB on web, file on mobile) as a durable,
/// cross-platform store, with an in-memory cache for speed.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'fitness_ai_access_token';
  static const _refreshTokenKey = 'fitness_ai_refresh_token';

  // In-memory session cache (shared across instances).
  static String? _accessMem;
  static String? _refreshMem;

  String? _fromHive(String key) {
    try {
      final v = HiveStorage.user.get(key);
      return (v is String && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// Read the stored access token (memory → durable Hive → secure storage).
  Future<String?> getAccessToken() async {
    if (_accessMem != null) return _accessMem;
    final hiveVal = _fromHive(_accessTokenKey);
    if (hiveVal != null) {
      _accessMem = hiveVal;
      return _accessMem;
    }
    try {
      _accessMem = await _storage.read(key: _accessTokenKey);
    } catch (_) {
      _accessMem = null;
    }
    return _accessMem;
  }

  /// Read the stored refresh token (memory → durable Hive → secure storage).
  Future<String?> getRefreshToken() async {
    if (_refreshMem != null) return _refreshMem;
    final hiveVal = _fromHive(_refreshTokenKey);
    if (hiveVal != null) {
      _refreshMem = hiveVal;
      return _refreshMem;
    }
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
    // Durable cross-platform store (survives PWA reload/eviction on web).
    try {
      await HiveStorage.user.put(_accessTokenKey, accessToken);
      await HiveStorage.user.put(_refreshTokenKey, refreshToken);
    } catch (_) {}
    // Secure storage as a secondary on mobile (best-effort).
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
      await HiveStorage.user.delete(_accessTokenKey);
      await HiveStorage.user.delete(_refreshTokenKey);
    } catch (_) {}
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
