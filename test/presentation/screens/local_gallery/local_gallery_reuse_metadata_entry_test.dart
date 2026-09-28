import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_action_coordinator.dart';
import 'package:nai_launcher/presentation/services/image_metadata_import_workflow.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

/// 【偏离上游】「复用参数」在我们这里有两条行为不同的入口：
/// 全屏查看器里只弹 toast 不跳生成页，列表卡片菜单仍按上游跳转。
/// 上游 ImageMetadataImportWorkflow.openGenerationPage 全仓无人传 false，
/// 这个分叉很容易在下次跟上游时被抹平，所以两条都钉一个用例。
void main() {
  final record = LocalImageRecord(
    path: 'gallery/image.png',
    size: 42,
    modifiedAt: DateTime(2025),
  );

  testWidgets('全屏查看器入口复用参数后不跳生成页', (tester) async {
    final harness = await _pumpCoordinator(tester);

    await harness.coordinator.importImageMetadataFromViewer(record);
    await tester.pumpAndSettle();

    expect(harness.appliedCount, 1);
    expect(harness.openedGenerationCount, 0);
  });

  testWidgets('列表卡片菜单入口复用参数后仍跳生成页', (tester) async {
    final harness = await _pumpCoordinator(tester);

    await harness.coordinator.routeImageAction(
      LocalGalleryImageAction(
        record: record,
        action: LocalImageContextAction.importMetadata,
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.appliedCount, 1);
    expect(harness.openedGenerationCount, 1);
  });
}

class _Harness {
  _Harness(this.coordinator, this._counters);

  final LocalGalleryActionCoordinator coordinator;
  final List<int> _counters;

  int get appliedCount => _counters[0];
  int get openedGenerationCount => _counters[1];
}

Future<_Harness> _pumpCoordinator(WidgetTester tester) async {
  final counters = <int>[0, 0];
  final workflow = ImageMetadataImportWorkflow(
    optionsPicker: (context, metadata) async =>
        const MetadataImportOptions(importPrompt: true),
    metadataApplier: (read, metadata, options, l10n) async {
      counters[0]++;
      return 1;
    },
    resultReporter: (context, result, appliedCount) {},
    generationPageOpener: (context) => counters[1]++,
  );

  late LocalGalleryActionCoordinator coordinator;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Consumer(
          builder: (context, ref, child) {
            coordinator = LocalGalleryActionCoordinator(
              ref: ref,
              context: () => context,
              mounted: () => context.mounted,
              metadataImportWorkflow: workflow,
              metadataLoader: (path) async =>
                  const NaiImageMetadata(prompt: '1girl'),
            );
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    ),
  );

  return _Harness(coordinator, counters);
}
