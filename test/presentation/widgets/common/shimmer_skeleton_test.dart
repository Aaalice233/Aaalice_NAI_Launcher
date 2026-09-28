import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/shimmer_skeleton.dart';

void main() {
  testWidgets('reduce motion renders a static semantic-free skeleton', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ShimmerSkeleton(height: 48, width: 120)),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ShimmerSkeleton),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(find.byType(ShimmerSkeleton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShimmerSkeleton),
        matching: find.bySemanticsLabel(RegExp('.+')),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('motion preference changes stop and resume shimmer', (
    tester,
  ) async {
    var disableAnimations = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: const ShimmerSkeleton(height: 48),
            );
          },
        ),
      ),
    );

    Finder shimmerAnimation() => find.descendant(
      of: find.byType(ShimmerSkeleton),
      matching: find.byType(AnimatedBuilder),
    );

    expect(shimmerAnimation(), findsOneWidget);
    setHostState(() => disableAnimations = true);
    await tester.pump();
    expect(shimmerAnimation(), findsNothing);

    setHostState(() => disableAnimations = false);
    await tester.pump();
    expect(shimmerAnimation(), findsOneWidget);
  });
}
