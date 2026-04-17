import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';
import 'package:prepare_with_atlas/features/problem_bank/presentation/problem_tile.dart';

void main() {
  final testProblem = Problem(
    id: 1,
    title: 'Design a URL shortener',
    description: 'Design a URL shortening service.',
    difficulty: 'easy',
    category: 'storage',
    createdAt: DateTime(2026, 4, 8),
  );

  Widget buildTile({void Function()? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: ProblemTile(
          problem: testProblem,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  group('ProblemTile', () {
    testWidgets('renders the problem title', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.text('Design a URL shortener'), findsOneWidget);
    });

    testWidgets('does NOT render difficulty text', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.text('easy'), findsNothing);
      expect(find.text('Easy'), findsNothing);
    });

    testWidgets('does NOT render category text', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.text('storage'), findsNothing);
      expect(find.text('Storage'), findsNothing);
    });

    testWidgets('does NOT render description text', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.text('Design a URL shortening service.'), findsNothing);
    });

    testWidgets('tapping triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTile(onTap: () => tapped = true));
      await tester.tap(find.byType(ProblemTile));
      expect(tapped, isTrue);
    });
  });
}
