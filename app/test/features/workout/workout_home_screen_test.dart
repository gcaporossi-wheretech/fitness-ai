import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/theme/app_theme.dart';
import 'package:fitness_ai/features/workout/presentation/workout_home_screen.dart';

void main() {
  group('WorkoutHomeScreen', () {
    testWidgets('shows FitnessAI title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkoutHomeScreen(),
          ),
        ),
      );

      expect(find.text('FitnessAI'), findsOneWidget);
    });

    testWidgets('shows empty state message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const WorkoutHomeScreen(),
          ),
        ),
      );

      expect(find.text('Nessuna scheda attiva'), findsOneWidget);
    });

    testWidgets('shows create plan button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const WorkoutHomeScreen(),
          ),
        ),
      );

      expect(find.text('Crea Scheda'), findsOneWidget);
    });

    testWidgets('shows AI coach button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const WorkoutHomeScreen(),
          ),
        ),
      );

      expect(find.text('Coach AI'), findsOneWidget);
    });
  });
}
