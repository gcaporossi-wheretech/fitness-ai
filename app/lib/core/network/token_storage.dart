import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for JWT tokens.
/// Uses flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences
/// on Android) to protect authentication tokens.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'fitness_ai_access_token';
  static const _refreshTokenKey = 'fitness_ai_refresh_token';

  /// Read the stored access token.
  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  /// Read the stored refresh token.
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  /// Save both tokens after login/register/refresh.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  /// Clear all tokens on logout.
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
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
