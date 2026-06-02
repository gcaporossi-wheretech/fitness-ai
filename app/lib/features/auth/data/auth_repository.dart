import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/auth/webauthn.dart' as webauthn;
import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/core/network/api_exception.dart';
import 'package:fitness_ai/core/network/token_storage.dart';
import 'package:fitness_ai/core/storage/hive_storage.dart';
import 'package:fitness_ai/features/auth/domain/user.dart';

/// Repository for authentication operations.
/// Handles API calls and local token/user persistence.
class AuthRepository {
  AuthRepository({
    required this.apiClient,
    required this.tokenStorage,
  });

  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  /// Register a new user account.
  Future<User> register({
    required String email,
    required String password,
    String? name,
    String language = 'it',
  }) async {
    try {
      final response = await apiClient.post(
        ApiConstants.authRegister,
        data: {
          'email': email,
          'password': password,
          if (name != null) 'name': name,
          'language': language,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      await tokenStorage.saveTokens(
        accessToken: tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      _cacheUser(user);
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Log in with email and password.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.post(
        ApiConstants.authLogin,
        data: {'email': email, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      await tokenStorage.saveTokens(
        accessToken: tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      _cacheUser(user);
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get the current user profile from API.
  Future<User> getProfile() async {
    try {
      final response = await apiClient.get(ApiConstants.authMe);
      final user = User.fromJson(response.data as Map<String, dynamic>);
      _cacheUser(user);
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Update user profile.
  Future<User> updateProfile(Map<String, dynamic> updates) async {
    try {
      final response = await apiClient.patch(
        ApiConstants.authMe,
        data: updates,
      );
      final user = User.fromJson(response.data as Map<String, dynamic>);
      _cacheUser(user);
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get cached user from Hive (for offline).
  User? getCachedUser() {
    final data = HiveStorage.user.get('profile');
    if (data == null) return null;
    return User.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Log out: clear tokens and cached user.
  Future<void> logout() async {
    await tokenStorage.clearTokens();
    await HiveStorage.user.delete('profile');
  }

  /// Check if user has stored tokens.
  Future<bool> isLoggedIn() => tokenStorage.hasTokens();

  void _cacheUser(User user) {
    HiveStorage.user.put('profile', user.toJson());
  }

  // ============================================================
  // WebAuthn (Face ID / passkey)
  // ============================================================

  static const _webauthnCredKey = 'webauthn_credential_id';

  /// The Face ID credential registered on THIS device, if any.
  String? get storedWebAuthnCredentialId {
    final v = HiveStorage.user.get(_webauthnCredKey);
    return (v is String && v.isNotEmpty) ? v : null;
  }

  /// Whether the current platform/browser supports WebAuthn.
  bool get webauthnSupported => webauthn.webauthnSupported();

  /// Register a passkey (Face ID) on this device. Requires an active session.
  Future<void> enableWebAuthn() async {
    try {
      final begin = await apiClient.post(ApiConstants.authWebauthnRegisterBegin);
      final opts = Map<String, dynamic>.from(begin.data as Map);
      final cred = await webauthn.webauthnRegister(opts);
      await apiClient.post(
        ApiConstants.authWebauthnRegisterComplete,
        data: {
          'credential_id': cred['credential_id'],
          'public_key': cred['public_key'],
          'device_name': 'Browser PWA',
        },
      );
      await HiveStorage.user.put(_webauthnCredKey, cred['credential_id']);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Log in using the device's registered passkey (Face ID).
  Future<User> loginWithWebAuthn() async {
    final credId = storedWebAuthnCredentialId;
    if (credId == null) {
      throw const ApiException(
        message: 'Face ID non configurato su questo dispositivo',
      );
    }
    try {
      final assertion = await webauthn.webauthnAuthenticate({
        'rp_id': Uri.base.host,
        'credential_id': credId,
      });
      final response = await apiClient.post(
        ApiConstants.authWebauthnLogin,
        data: assertion,
      );
      final data = response.data as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      await tokenStorage.saveTokens(
        accessToken: tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      _cacheUser(user);
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Provider for auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
