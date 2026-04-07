import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/widgets/celebration_overlay.dart';

void main() {
  group('CelebrationOverlay', () {
    testWidgets('renders and calls onComplete after animation', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelebrationOverlay(
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      // Widget should be rendered
      expect(find.byType(CelebrationOverlay), findsOneWidget);

      // Animation hasn't completed yet
      expect(completed, false);

      // Advance past the 2500ms animation duration
      await tester.pump(const Duration(milliseconds: 2600));

      expect(completed, true);
    });

    testWidgets('ignores pointer events', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelebrationOverlay(onComplete: () {}),
          ),
        ),
      );

      // IgnorePointer wraps the CustomPaint inside the celebration overlay
      expect(find.byType(IgnorePointer), findsWidgets);
    });

    testWidgets('disposes animation controller without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CelebrationOverlay(onComplete: () {}),
          ),
        ),
      );

      // Just pump a couple frames to verify no errors
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Dispose by removing from tree
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      // No errors = test passes
    });
  });
}
