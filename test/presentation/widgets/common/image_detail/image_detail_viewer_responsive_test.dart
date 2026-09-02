import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_thumbnail_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'single image adapts from compact to wide metadata presentation',
    (tester) async {
      final image = _TestImageData('single', _validPngBytes);

      for (final width in [360.0, 700.0, 900.0, 1200.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        await _pumpViewer(tester, images: [image]);
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('1 / 1'), findsOneWidget, reason: 'width=$width');
        expect(find.byType(DetailThumbnailBar), findsNothing);
        expect(
          find.byType(DetailMetadataPanel),
          width >= 1100 ? findsOneWidget : findsNothing,
          reason: 'width=$width',
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('three-times text scale keeps metadata action reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [_TestImageData('scaled', _validPngBytes)],
      textScaler: const TextScaler.linear(3),
    );
    await tester.pump();

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact metadata action opens the adaptive panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [_TestImageData('panel', _validPngBytes)],
      textScaler: const TextScaler.linear(3),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DetailMetadataPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple images page with arrows, thumbnails, and keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final images = [
      _TestImageData('first', _validPngBytes),
      _TestImageData('second', _validPngBytes),
      _TestImageData('third', _validPngBytes),
    ];

    await _pumpViewer(tester, images: images);
    await tester.pump();

    expect(find.byType(DetailThumbnailBar), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed image replaces loading state with explicit error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [
        _TestImageData('broken', Uint8List.fromList([1, 2, 3])),
      ],
      showMetadataPanel: false,
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.text('Failed to load image'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('top-bar operations dispatch for the current page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <String>[];
    final images = [
      _TestImageData('one', _validPngBytes),
      _TestImageData('two', _validPngBytes),
    ];

    await _pumpViewer(
      tester,
      images: images,
      callbacks: ImageDetailCallbacks(
        onSave: (image) async {
          saved.add(image.identifier);
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pump();

    expect(saved, ['two']);
  });

  testWidgets('close action returns to the previous route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = _TestImageData('route', _validPngBytes);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _FakeShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ImageDetailViewer.showSingle(
                  context,
                  image: image,
                  showMetadataPanel: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageDetailViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ImageDetailViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}

Future<void> _pumpViewer(
  WidgetTester tester, {
  required List<ImageDetailData> images,
  ImageDetailCallbacks? callbacks,
  bool showMetadataPanel = true,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _FakeShortcutConfigNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: ImageDetailViewer(
          images: images,
          callbacks: callbacks,
          showMetadataPanel: showMetadataPanel,
        ),
      ),
    ),
  );
}

final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _TestImageData implements ImageDetailData {
  _TestImageData(this.identifier, this.bytes);

  final Uint8List bytes;

  @override
  final String identifier;

  @override
  FileInfo? get fileInfo => null;

  @override
  ImageProvider<Object> getImageProvider() => MemoryImage(bytes);

  @override
  Future<Uint8List> getImageBytes() async => bytes;

  @override
  bool get isFavorite => false;

  @override
  NaiImageMetadata? get metadata => null;

  @override
  bool get preserveOriginalBytesOnSave => true;

  @override
  bool get showCopyButton => false;

  @override
  bool get showFavoriteButton => false;

  @override
  bool get showSaveButton => true;
}
