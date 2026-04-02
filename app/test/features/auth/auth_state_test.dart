import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/auth/domain/auth_state.dart';
import 'package:fitness_ai/features/auth/domain/user.dart';

void main() {
  group('AuthState', () {
    test('initial state is AuthInitial', () {
      const state = AuthState.initial();
      expect(state, isA<AuthInitial>());
    });

    test('loading state is AuthLoading', () {
      const state = AuthState.loading();
      expect(state, isA<AuthLoading>());
    });

    test('unauthenticated state is AuthUnauthenticated', () {
      const state = AuthState.unauthenticated();
      expect(state, isA<AuthUnauthenticated>());
    });

    test('authenticated state holds user', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        createdAt: DateTime.now(),
      );
      final state = AuthState.authenticated(user);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user.email, 'test@example.com');
    });

    test('error state holds message', () {
      const state = AuthState.error('Invalid credentials');
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, 'Invalid credentials');
    });

    test('pattern matching works on sealed class', () {
      const AuthState state = AuthState.unauthenticated();
      final result = switch (state) {
        AuthInitial() => 'initial',
        AuthLoading() => 'loading',
        AuthAuthenticated() => 'authenticated',
        AuthUnauthenticated() => 'unauthenticated',
        AuthError() => 'error',
      };
      expect(result, 'unauthenticated');
    });
  });
}
