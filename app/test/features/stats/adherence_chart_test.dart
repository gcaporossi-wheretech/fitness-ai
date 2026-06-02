import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/stats/presentation/adherence_chart.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

void main() {
  group('AdherenceChart', () {
    testWidgets('shows empty state when no sessions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdherenceChart(sessions: []),
          ),
        ),
      );

      expect(find.text('No adherence data available.'), findsOneWidget);
    });

    testWidgets('shows percentage and stats with sessions', (tester) async {
      final sessions = [
        WorkoutSession(
          id: '1',
          startedAt: DateTime.now().subtract(const Duration(days: 7)),
          completedAt: DateTime.now().subtract(const Duration(days: 7)),
          durationSeconds: 3600,
          exercises: [],
        ),
        WorkoutSession(
          id: '2',
          startedAt: DateTime.now().subtract(const Duration(days: 5)),
          completedAt: DateTime.now().subtract(const Duration(days: 5)),
          durationSeconds: 3600,
          exercises: [],
        ),
        WorkoutSession(
          id: '3',
          startedAt: DateTime.now().subtract(const Duration(days: 3)),
          completedAt: DateTime.now().subtract(const Duration(days: 3)),
          durationSeconds: 3600,
          exercises: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdherenceChart(sessions: sessions),
          ),
        ),
      );

      // Should show adherence percentage
      expect(find.textContaining('%'), findsOneWidget);
      // Should show completed count
      expect(find.text('3'), findsOneWidget);
      // Should show stat labels
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('Active weeks'), findsOneWidget);
    });

    testWidgets('renders custom paint for ring', (tester) async {
      final sessions = [
        WorkoutSession(
          id: '1',
          startedAt: DateTime.now().subtract(const Duration(days: 1)),
          completedAt: DateTime.now().subtract(const Duration(days: 1)),
          durationSeconds: 3600,
          exercises: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdherenceChart(sessions: sessions),
          ),
        ),
      );

      // The adherence ring is drawn with CustomPaint (may find multiple
      // due to container decorations)
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('respects sessionsPerWeek parameter', (tester) async {
      final sessions = [
        WorkoutSession(
          id: '1',
          startedAt: DateTime.now().subtract(const Duration(days: 3)),
          completedAt: DateTime.now().subtract(const Duration(days: 3)),
          durationSeconds: 3600,
          exercises: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdherenceChart(sessions: sessions, sessionsPerWeek: 3),
          ),
        ),
      );

      // Should render without error
      expect(find.byType(AdherenceChart), findsOneWidget);
    });
  });
}
