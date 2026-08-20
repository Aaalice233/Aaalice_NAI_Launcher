import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_detail/vibe_preview_drop_zone.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_detail_viewer.dart';
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';

void main() {
  testWidgets('关闭详情页不会自动保存参数', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = _buildEntry();
    final storage = _FakeVibeLibraryStorageService(entry);
    var saveCount = 0;

    await tester.pumpWidget(
      _wrapWithHost(
        entry: entry,
        storage: storage,
        onSaveParams: (_, __, ___) async {
          saveCount++;
          return entry;
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(storage.getEntryCalls, 0);

    final infoSlider = tester.widget<Slider>(find.byType(Slider).at(1));
    infoSlider.onChanged?.call(0.1);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(saveCount, 0);
  });

  testWidgets('点保存参数后才触发显式保存回调', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = _buildEntry();
    var saveCount = 0;

    await tester.pumpWidget(
      _wrapWithHost(
        entry: entry,
        storage: _FakeVibeLibraryStorageService(entry),
        onSaveParams: (_, strength, infoExtracted) async {
          saveCount++;
          return entry.copyWith(
            strength: strength,
            infoExtracted: infoExtracted,
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final infoSlider = tester.widget<Slider>(find.byType(Slider).at(1));
    infoSlider.onChanged?.call(0.1);
    await tester.pump();

    await tester.tap(find.text('保存参数'));
    await tester.pump();

    expect(saveCount, 1);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('没有原图数据时详情页不显示信息提取调节项', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = _buildEntry().copyWith(
      rawImageData: null,
      vibeThumbnail: Uint8List.fromList(const [1, 2, 3, 4]),
    );

    await tester.pumpWidget(
      _wrapWithHost(
        entry: entry,
        storage: _FakeVibeLibraryStorageService(entry),
        onSaveParams: (_, __, ___) async => entry,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('信息提取'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('bundle 详情主预览优先使用子 Vibe 原图而不是缩略图', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rawImage = _pngBytes(255, 0, 0);
    final previewImage = _pngBytes(0, 0, 255);
    final entry = VibeLibraryEntry(
      id: 'bundle-entry',
      name: 'Bundle Vibe',
      vibeDisplayName: 'first',
      vibeEncoding: 'encoding-first',
      vibeThumbnail: previewImage,
      rawImageData: rawImage,
      strength: 0.6,
      infoExtracted: 0.2,
      sourceTypeIndex: VibeSourceType.naiv4vibebundle.index,
      createdAt: DateTime(2026, 5, 14),
      filePath: r'G:\AIdarw\vibes\bundle.naiv4vibebundle',
      bundledVibeNames: const ['first'],
      bundledVibePreviews: [previewImage],
      bundledVibeEncodings: const ['encoding-first'],
      bundledVibeStrengths: const [0.6],
      bundledVibeInfoExtracted: const [0.2],
    );
    final bundleChildren = [
      VibeReference(
        displayName: 'first',
        vibeEncoding: 'encoding-first',
        thumbnail: previewImage,
        rawImageData: rawImage,
        strength: 0.6,
        infoExtracted: 0.2,
        sourceType: VibeSourceType.naiv4vibebundle,
      ),
    ];
    final storage = _FakeVibeLibraryStorageService(
      entry,
      bundleChildren: bundleChildren,
    );

    await tester.pumpWidget(
      _wrapWithHost(
        entry: entry,
        storage: storage,
        bundleVibes: bundleChildren,
        onSaveParams: (_, __, ___) async => entry,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final previewZone = tester.widget<VibePreviewDropZone>(
      find.byType(VibePreviewDropZone).first,
    );
    expect(previewZone.imageBytes, same(rawImage));
    expect(previewZone.imageBytes, isNot(same(previewImage)));
    expect(storage.getEntryCalls, 0);
    expect(storage.loadBundleChildCalls, 0);

    final decodedImage = tester.widget<DecodedMemoryImage>(
      find
          .descendant(
            of: find.byType(VibePreviewDropZone),
            matching: find.byType(DecodedMemoryImage),
          )
          .first,
    );
    expect(decodedImage.gaplessPlayback, isTrue);
  });

  testWidgets('后台解析详情时立即显示加载层，完成后只使用解析结果', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final initialEntry = _buildEntry().copyWith(
      vibeThumbnail: null,
      rawImageData: null,
    );
    final rawImage = _pngBytes(32, 64, 96);
    final actualEntry = initialEntry.copyWith(
      vibeThumbnail: rawImage,
      rawImageData: rawImage,
    );
    final storage = _FakeVibeLibraryStorageService(actualEntry);
    final detailData = Completer<VibeLibraryDetailData>();

    await tester.pumpWidget(
      _wrapWithHost(
        entry: initialEntry,
        storage: storage,
        detailDataFuture: detailData.future,
        onSaveParams: (_, __, ___) async => actualEntry,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('加载中...'), findsOneWidget);
    expect(find.byType(VibePreviewDropZone), findsNothing);

    detailData.complete(VibeLibraryDetailData(entry: actualEntry));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final previewZone = tester.widget<VibePreviewDropZone>(
      find.byType(VibePreviewDropZone).first,
    );
    expect(previewZone.imageBytes, same(rawImage));
    expect(storage.getEntryCalls, 0);
    expect(storage.loadBundleChildCalls, 0);
  });
}

Widget _wrapWithHost({
  required VibeLibraryEntry entry,
  required VibeLibraryStorageService storage,
  Future<VibeLibraryDetailData>? detailDataFuture,
  List<VibeReference> bundleVibes = const [],
  required Future<VibeLibraryEntry?> Function(
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  )
  onSaveParams,
}) {
  return ProviderScope(
    overrides: [
      vibeLibraryStorageServiceProvider.overrideWithValue(storage),
      shortcutConfigNotifierProvider.overrideWith(
        _FakeShortcutConfigNotifier.new,
      ),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  VibeDetailViewer.show(
                    context,
                    entry: entry,
                    detailDataFuture: detailDataFuture,
                    bundleVibes: bundleVibes,
                    callbacks: VibeDetailCallbacks(
                      onSaveParams: (entry, strength, infoExtracted, _) {
                        return onSaveParams(entry, strength, infoExtracted);
                      },
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

VibeLibraryEntry _buildEntry() {
  final imageBytes = Uint8List.fromList(const [1, 2, 3, 4]);
  return VibeLibraryEntry(
    id: 'entry-1',
    name: 'Library Vibe',
    vibeDisplayName: 'Library Vibe',
    vibeEncoding: 'encoded-before',
    vibeThumbnail: imageBytes,
    rawImageData: imageBytes,
    strength: 0.6,
    infoExtracted: 0.2,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    createdAt: DateTime(2026, 4, 15),
  );
}

Uint8List _pngBytes(int r, int g, int b) {
  final image = img.Image(width: 1, height: 1);
  image.setPixelRgb(0, 0, r, g, b);
  return Uint8List.fromList(img.encodePng(image));
}

class _FakeVibeLibraryStorageService extends VibeLibraryStorageService {
  _FakeVibeLibraryStorageService(this.entry, {this.bundleChildren = const []});

  final VibeLibraryEntry entry;
  final List<VibeReference> bundleChildren;
  int getEntryCalls = 0;
  int loadBundleChildCalls = 0;

  @override
  Future<VibeLibraryEntry?> getEntry(String id) async {
    getEntryCalls++;
    if (id != entry.id) {
      return null;
    }
    return entry;
  }

  @override
  Future<VibeReference?> loadBundleChildVibe(String id, int childIndex) async {
    loadBundleChildCalls++;
    if (id != entry.id ||
        childIndex < 0 ||
        childIndex >= bundleChildren.length) {
      return null;
    }
    return bundleChildren[childIndex];
  }
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
