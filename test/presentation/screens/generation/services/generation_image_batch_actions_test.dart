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

void main() {
  final images = [
    for (final id in ['a', 'b'])
      GeneratedImage(id: id, bytes: Uint8List(0), width: 1, height: 1),
  ];

  Future<ImageCardAction> saveAction(
    WidgetTester tester,
    ProviderContainer container,
    Future<bool> Function(List<GeneratedImage> images) saveImages,
  ) async {
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
                saveImages: saveImages,
              ).build();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return actions.singleWhere((action) => action.id == ImageCardActionId.save);
  }

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
    final action = await saveAction(tester, container, (images) async {
      received = images;
      return true;
    });

    await action.invoke();

    expect(received, images);
    expect(
      container.read(generationImageCardSelectionProvider).selectedIds,
      isEmpty,
    );
  });

  testWidgets('批量保存部分失败时保留选择，方便重试', (tester) async {
    final container = selectedContainer();
    addTearDown(container.dispose);
    final action = await saveAction(tester, container, (_) async => false);

    await action.invoke();

    expect(container.read(generationImageCardSelectionProvider).selectedIds, {
      'a',
      'b',
    });
  });
}
