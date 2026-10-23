import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_viewport_memory_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_dialog_controller.dart';

void main() {
  testWidgets('responsive transition tolerates two attached list positions', (
    tester,
  ) async {
    final controller = FixedTagsDialogController();
    addTearDown(controller.dispose);
    final listController = controller.listControllerFor(
      FixedTagPromptType.positive,
      filtered: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (var index = 0; index < 2; index++)
                Expanded(
                  child: ListView(
                    controller: listController,
                    children: const [SizedBox(height: 800)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(listController.positions, hasLength(2));
    expect(
      controller.scrollOffsetFor(FixedTagPromptType.positive, filtered: false),
      isNonNegative,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('browse lists resume from shared memory, filtered lists do not', (
    tester,
  ) async {
    final memory = FixedTagsViewportMemory();
    Widget list(ScrollController listController) => MaterialApp(
      home: SizedBox(
        height: 300,
        child: ListView.builder(
          key: ObjectKey(listController),
          controller: listController,
          itemExtent: 50,
          itemCount: 100,
          itemBuilder: (_, index) => Text('item $index'),
        ),
      ),
    );

    final first = FixedTagsDialogController(viewportMemory: memory);
    await tester.pumpWidget(
      list(
        first.listControllerFor(FixedTagPromptType.negative, filtered: false),
      ),
    );
    first
        .listControllerFor(FixedTagPromptType.negative, filtered: false)
        .jumpTo(900);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();

    final reopened = FixedTagsDialogController(viewportMemory: memory);
    addTearDown(reopened.dispose);
    final browse = reopened.listControllerFor(
      FixedTagPromptType.negative,
      filtered: false,
    );
    await tester.pumpWidget(list(browse));
    expect(browse.offset, 900);
    expect(
      memory
          .browseViewport(FixedTagsSurface.sidebar, FixedTagPromptType.negative)
          .pixels,
      0,
    );

    final filtered = reopened.listControllerFor(
      FixedTagPromptType.negative,
      filtered: true,
    );
    await tester.pumpWidget(list(filtered));
    expect(filtered.offset, 0);
    filtered.jumpTo(300);
    await tester.pump();
    expect(
      memory
          .browseViewport(FixedTagsSurface.dialog, FixedTagPromptType.negative)
          .pixels,
      900,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('mobile prompt tab is shared through viewport memory', () {
    final memory = FixedTagsViewportMemory();
    final first = FixedTagsDialogController(viewportMemory: memory);
    addTearDown(first.dispose);
    first.selectMobilePromptType(FixedTagPromptType.negative);

    final reopened = FixedTagsDialogController(viewportMemory: memory);
    addTearDown(reopened.dispose);
    expect(reopened.mobilePromptType, FixedTagPromptType.negative);
  });
}
