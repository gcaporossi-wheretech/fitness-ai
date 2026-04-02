import 'package:fitness_ai/features/auth/domain/user.dart';

/// Authentication state managed by AuthNotifier.
/// Uses Dart 3 sealed classes for exhaustive pattern matching.
sealed class AuthState {
  const AuthState();

  /// Initial state before checking stored tokens.
  const factory AuthState.initial() = AuthInitial;

  /// Checking stored tokens on app start.
  const factory AuthState.loading() = AuthLoading;

  /// User is authenticated.
  const factory AuthState.authenticated(User user) = AuthAuthenticated;

  /// User is not authenticated (no tokens or expired).
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// Authentication error occurred.
  const factory AuthState.error(String message) = AuthError;
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
