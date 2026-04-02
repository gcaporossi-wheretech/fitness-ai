import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/network/api_exception.dart';
import 'package:fitness_ai/features/auth/data/auth_repository.dart';
import 'package:fitness_ai/features/auth/domain/auth_state.dart';

/// Manages authentication state across the app.
/// Handles login, register, logout, and session restoration.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Check stored session on first build
    _checkStoredSession();
    return const AuthState.initial();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Check if there is a stored session and restore it.
  Future<void> _checkStoredSession() async {
    state = const AuthState.loading();
    try {
      final isLoggedIn = await _repo.isLoggedIn();
      if (!isLoggedIn) {
        state = const AuthState.unauthenticated();
        return;
      }

      // Try to get profile from API (validates token)
      try {
        final user = await _repo.getProfile();
        state = AuthState.authenticated(user);
      } on ApiException {
        // Token expired, try cached user or go to unauthenticated
        final cached = _repo.getCachedUser();
        if (cached != null) {
          state = AuthState.authenticated(cached);
        } else {
          state = const AuthState.unauthenticated();
        }
      }
    } catch (e) {
      // Offline: use cached user if available
      final cached = _repo.getCachedUser();
      if (cached != null) {
        state = AuthState.authenticated(cached);
      } else {
        state = const AuthState.unauthenticated();
      }
    }
  }

  /// Register a new account.
  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    state = const AuthState.loading();
    try {
      final user = await _repo.register(
        email: email,
        password: password,
        name: name,
      );
      state = AuthState.authenticated(user);
    } on ApiException catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// Log in with email and password.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final user = await _repo.login(email: email, password: password);
      state = AuthState.authenticated(user);
    } on ApiException catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// Log out and clear session.
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }
}

/// Global auth state provider.
final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
