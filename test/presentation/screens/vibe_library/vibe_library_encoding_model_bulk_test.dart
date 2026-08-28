import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_bulk_operation_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_category_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_selection_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_screen.dart';

void main() {
  for (final scenario in [
    (name: '部分失败', success: 1, failed: 1),
    (name: '全部失败', success: 0, failed: 2),
  ]) {
    testWidgets('批量标记 encoding model ${scenario.name}仍显示 HEAD 成功 Toast 和成功计数', (
      tester,
    ) async {
      final operation = Completer<VibeBulkOperationResult>();
      final notifier = _EncodingModelBulkNotifier(operation.future);
      final container = _createContainer(notifier);
      addTearDown(container.dispose);

      await _pumpScreen(tester, container);
      await _startMarking(tester, container);

      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(
        container.read(vibeLibrarySelectionNotifierProvider).isActive,
        isTrue,
      );

      operation.complete(
        VibeBulkOperationResult.fromResult(
          success: scenario.success,
          failed: scenario.failed,
          errors: [
            for (var index = 0; index < scenario.failed; index++)
              VibeBulkOperationError(
                VibeBulkOperationErrorCode.processFileFailed,
                itemName: 'failed-$index',
              ),
          ],
        ),
      );
      await tester.pump();

      expect(notifier.requestedIds, ['first', 'second']);
      expect(notifier.requestedModel, ImageModels.animeDiffusionV45Full);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('已标记 ${scenario.success} 个Vibe的编码模型'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
      expect(
        container.read(vibeLibrarySelectionNotifierProvider).isActive,
        isFalse,
      );
      await tester.pump(const Duration(seconds: 4));
    });
  }
}

ProviderContainer _createContainer(_EncodingModelBulkNotifier notifier) {
  return ProviderContainer(
    overrides: [
      generationParamsNotifierProvider.overrideWith(
        _TestGenerationParamsNotifier.new,
      ),
      vibeLibraryNotifierProvider.overrideWith(() => notifier),
      vibeLibraryCategoryNotifierProvider.overrideWith(
        _TestVibeLibraryCategoryNotifier.new,
      ),
    ],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VibeLibraryScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _startMarking(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(vibeLibrarySelectionNotifierProvider.notifier).selectAll(
    const ['first', 'second'],
  );
  container.read(vibeLibrarySelectionNotifierProvider.notifier).enter();
  await tester.pump();
  await tester.tap(find.byIcon(Icons.model_training_outlined));
  await tester.pump();
  await tester.tap(find.text('确定'));
  await tester.pump();
}

class _EncodingModelBulkNotifier extends VibeLibraryNotifier {
  _EncodingModelBulkNotifier(this.result);

  final Future<VibeBulkOperationResult> result;
  List<String>? requestedIds;
  String? requestedModel;

  @override
  VibeLibraryState build() =>
      VibeLibraryState(entries: [_entry('first'), _entry('second')]);

  @override
  Future<void> initialize() async {}

  @override
  Future<VibeBulkOperationResult> bulkUpdateEncodingModel(
    Iterable<String> ids,
    String model,
  ) {
    requestedIds = ids.toList();
    requestedModel = model;
    return result;
  }
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() =>
      const ImageParams(model: ImageModels.animeDiffusionV45Full);
}

class _TestVibeLibraryCategoryNotifier extends VibeLibraryCategoryNotifier {
  @override
  VibeLibraryCategoryState build() => const VibeLibraryCategoryState();
}

VibeLibraryEntry _entry(String id) => VibeLibraryEntry(
  id: id,
  name: id,
  vibeDisplayName: id,
  vibeEncoding: 'encoding',
  createdAt: DateTime(2025),
);
