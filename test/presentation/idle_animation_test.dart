import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/prompt/components/tag_chip/tag_chip_animations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TagView skips entrance animation when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: TagView(
                tags: const [PromptTag(id: '1', text: '1girl')],
                onTagsChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TagChipEntranceBuilder), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('TagView synchronizes shimmer with loading and motion changes', (
    tester,
  ) async {
    var disableAnimations = true;
    var isLoading = true;
    late StateSetter setHostState;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: disableAnimations),
                child: Scaffold(
                  body: TagView(
                    tags: const [PromptTag(id: '1', text: '1girl')],
                    onTagsChanged: (_) {},
                    isLoading: isLoading,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(TagChipShimmerBuilder), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 80 && widget.height == 32,
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    setHostState(() => disableAnimations = false);
    await tester.pump();
    expect(find.byType(TagChipShimmerBuilder), findsNWidgets(8));

    setHostState(() => isLoading = false);
    await tester.pump();
    expect(find.byType(TagChipShimmerBuilder), findsNothing);
    await tester.pumpAndSettle();

    setHostState(() {
      disableAnimations = true;
      isLoading = true;
    });
    await tester.pump();
    expect(find.byType(TagChipShimmerBuilder), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('EditorCanvas settles immediately when there is no selection', (
    tester,
  ) async {
    final state = EditorState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EditorCanvas(state: state)),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    state.dispose();
  });
}
