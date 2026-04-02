import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitness_ai/features/auth/domain/auth_state.dart';
import 'package:fitness_ai/features/auth/presentation/auth_notifier.dart';
import 'package:fitness_ai/features/auth/presentation/login_screen.dart';
import 'package:fitness_ai/features/auth/presentation/register_screen.dart';
import 'package:fitness_ai/features/workout/presentation/workout_home_screen.dart';
import 'package:fitness_ai/features/history/presentation/history_screen.dart';
import 'package:fitness_ai/features/stats/presentation/stats_screen.dart';
import 'package:fitness_ai/features/profile/presentation/profile_screen.dart';

/// Navigation key for the shell (tab) navigator.
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Shell with bottom navigation bar for the main app tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _indexForLocation(String location) {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/stats')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          const routes = ['/workout', '/history', '/stats', '/profile'];
          context.go(routes[index]);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Storico',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Grafici',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}

/// GoRouter configuration with auth redirect.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/workout',
    redirect: (context, state) {
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoading = authState is AuthInitial || authState is AuthLoading;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // While loading, don't redirect
      if (isLoading) return null;

      // If not authenticated and not on auth route, go to login
      if (!isAuthenticated && !isAuthRoute) return '/login';

      // If authenticated and on auth route, go to workout
      if (isAuthenticated && isAuthRoute) return '/workout';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/workout',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WorkoutHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/stats',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StatsScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
