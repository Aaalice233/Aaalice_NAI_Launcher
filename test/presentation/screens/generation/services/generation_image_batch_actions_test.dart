import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/image_card_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/services/generation_image_batch_actions.dart';
import 'package:nai_launcher/presentation/screens/generation/services/generation_image_deletion.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';

typedef _BatchSave = Future<bool> Function(List<GeneratedImage> images);

void main() {
  final images = [
    for (final id in ['a', 'b'])
      GeneratedImage(id: id, bytes: Uint8List(0), width: 1, height: 1),
  ];

  Future<bool> unexpectedSave(List<GeneratedImage> _) async =>
      throw StateError('unexpected batch save');

  Future<List<ImageCardAction>> batchActions(
    WidgetTester tester,
    ProviderContainer container, {
    _BatchSave? saveImages,
    _BatchSave? saveImagesToFolder,
  }) async {
    late List<ImageCardAction> actions;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Consumer(
            builder: (context, ref, _) {
              actions = GenerationImageBatchActions(
                context: context,
                images: images,
                selection: ref.read(
                  generationImageCardSelectionProvider.notifier,
                ),
                deletion: GenerationImageDeletion(context: context, ref: ref),
                saveImages: saveImages ?? unexpectedSave,
                saveImagesToFolder: saveImagesToFolder ?? unexpectedSave,
              ).build();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return actions;
  }

  ImageCardAction actionOf(
    List<ImageCardAction> actions,
    ImageCardActionId id,
  ) => actions.singleWhere((action) => action.id == id);

  ProviderContainer selectedContainer() {
    final container = ProviderContainer();
    container.read(generationImageCardSelectionProvider.notifier)
      ..enterAndSelect('a')
      ..enterAndSelect('b');
    return container;
  }

  testWidgets('批量保存交给共用保存流程，全部成功后取消选择', (tester) async {
    final container = selectedContainer();
    addTearDown(container.dispose);
    List<GeneratedImage>? received;
    final actions = await batchActions(
      tester,
      container,
      saveImages: (images) async {
        received = images;
        return true;
      },
    );

    await actionOf(actions, ImageCardActionId.save).invoke();

    expect(received, images);
    expect(
      container.read(generationImageCardSelectionProvider).selectedIds,
      isEmpty,
    );
  });

  testWidgets('批量保存部分失败时保留选择，方便重试', (tester) async {
    final container = selectedContainer();
    addTearDown(container.dispose);
    final actions = await batchActions(
      tester,
      container,
      saveImages: (_) async => false,
    );

    await actionOf(actions, ImageCardActionId.save).invoke();

    expect(container.read(generationImageCardSelectionProvider).selectedIds, {
      'a',
      'b',
    });
  });

  testWidgets('批量另存为紧跟保存，归入管理分组', (tester) async {
    final container = selectedContainer();
    addTearDown(container.dispose);
    final actions = await batchActions(tester, container);

    final saveAs = actionOf(actions, ImageCardActionId.saveAs);
    expect(saveAs.label, '另存为到文件夹…');
    expect(saveAs.supportsBatch, isTrue);
    expect(saveAs.group, ImageCardActionGroup.manage);
    final orderedIds = orderedImageCardActions(
      actions,
    ).map((action) => action.id).toList();
    expect(
      orderedIds.indexOf(ImageCardActionId.saveAs),
      orderedIds.indexOf(ImageCardActionId.save) + 1,
    );
  });

  testWidgets('批量另存为全部成功后取消选择', (tester) async {
    final container = selectedContainer();
    addTearDown(container.dispose);
    List<GeneratedImage>? received;
    final actions = await batchActions(
      tester,
      container,
      saveImagesToFolder: (images) async {
        received = images;
        return true;
      },
    );

    await actionOf(actions, ImageCardActionId.saveAs).invoke();

    expect(received, images);
    expect(
      container.read(generationImageCardSelectionProvider).selectedIds,
      isEmpty,
    );
  });

  testWidgets('批量另存为失败或取消选择文件夹时保留选择', (tester) async {
    final container = selectedContainer();
    addTearDown(container.dispose);
    final actions = await batchActions(
      tester,
      container,
      saveImagesToFolder: (_) async => false,
    );

    await actionOf(actions, ImageCardActionId.saveAs).invoke();

    expect(container.read(generationImageCardSelectionProvider).selectedIds, {
      'a',
      'b',
    });
  });
}
