import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_picker_card/image_picker_card.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

void main() {
  setUp(() {
    FilePicker.platform = _FakeFilePicker(Future.value());
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('empty card fits 320-1600 widths, 3x text, and short height', (
    tester,
  ) async {
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      await _pumpCard(
        tester,
        width: width,
        height: width == 320 ? 64 : 100,
        textScaler: width == 320
            ? const TextScaler.linear(3)
            : TextScaler.noScaling,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        card: const ImagePickerCard(
          label: 'Choose an image with a deliberately long label',
          hintText: 'Optional image',
          icon: Icons.add_photo_alternate_outlined,
          enableDragDrop: false,
        ),
      );

      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('touch tap selects an image and loading remains bounded', (
    tester,
  ) async {
    final original = FilePicker.platform;
    final pending = Completer<FilePickerResult?>();
    final picker = _FakeFilePicker(pending.future);
    FilePicker.platform = picker;
    addTearDown(() => FilePicker.platform = original);
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );

    ImagePickerResult? selected;
    await _pumpCard(
      tester,
      width: 320,
      height: 72,
      textScaler: const TextScaler.linear(3),
      card: ImagePickerCard(
        label: 'Choose image',
        hintText: 'Touch to browse',
        icon: Icons.image_outlined,
        onImageSelected: (bytes, fileName, path) {
          selected = ImagePickerResult(
            bytes: bytes,
            fileName: fileName,
            path: path,
          );
        },
      ),
    );

    await tester.tap(find.byType(ImagePickerCard));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DropRegion), findsNothing);
    expect(tester.takeException(), isNull);

    pending.complete(
      FilePickerResult([
        PlatformFile(
          name: 'touch.png',
          size: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(selected?.fileName, 'touch.png');
    expect(selected?.bytes, Uint8List.fromList([1, 2, 3]));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('picker errors are reported and clear remains touch reachable', (
    tester,
  ) async {
    final original = FilePicker.platform;
    FilePicker.platform = _ThrowingFilePicker();
    addTearDown(() => FilePicker.platform = original);
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );

    String? error;
    await _pumpCard(
      tester,
      width: 320,
      card: ImagePickerCard(
        label: 'Selected image',
        icon: Icons.image_outlined,
        onError: (value) => error = value,
      ),
    );
    await tester.tap(find.byType(ImagePickerCard));
    await tester.pumpAndSettle();
    expect(error, contains('denied'));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    var cleared = false;
    await _pumpCard(
      tester,
      width: 320,
      card: ImagePickerCard(
        label: 'Selected image',
        icon: Icons.image_outlined,
        selectedPath:
            r'C:\very\long\directory\whose\name\must\not\overflow\final-image.png',
        onClear: () => cleared = true,
        onTap: () => fail('clear must not reopen the picker'),
      ),
    );
    expect(find.text('final-image.png'), findsOneWidget);
    final clearTarget = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(InkWell),
      ),
    );
    expect(clearTarget, const Size.square(48));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(cleared, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid preview falls back and desktop drag state is visible', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    await _pumpCard(
      tester,
      width: 420,
      card: ImagePickerCard(
        label: 'Broken preview',
        icon: Icons.broken_image_outlined,
        selectedImage: Uint8List.fromList([0, 1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    await _pumpCard(
      tester,
      width: 420,
      card: const ImagePickerCard(
        label: 'Drop image',
        icon: Icons.image_outlined,
      ),
    );
    final region = tester.widget<DropRegion>(find.byType(DropRegion));
    final session = _TestDropSession();
    final operation = region.onDropOver(
      DropOverEvent(
        session: session,
        position: DropPosition(local: Offset.zero, global: Offset.zero),
      ),
    );
    expect(operation, DropOperation.copy);
    await tester.pump();
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);

    region.onDropLeave?.call(DropEvent(session: session));
    await tester.pump();
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required double width,
  double height = 100,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  required ImagePickerCard card,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 600),
          textScaler: textScaler,
          padding: padding,
        ),
        child: Scaffold(
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, height: height, child: card),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TestDropSession with Diagnosticable implements DropSession {
  final _disposed = ValueNotifier(false);

  @override
  Set<DropOperation> get allowedOperations => {DropOperation.copy};

  @override
  List<DropItem> get items => const [];

  @override
  Listenable get onDisposed => _disposed;
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final Future<FilePickerResult?> result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) => result;
}

class _ThrowingFilePicker extends _FakeFilePicker {
  _ThrowingFilePicker() : super(Future.value());

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    throw StateError('denied');
  }
}
