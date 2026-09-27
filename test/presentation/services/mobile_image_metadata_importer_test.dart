import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/services/mobile_image_metadata_importer.dart';

void main() {
  testWidgets('iOS 的来源面板有相册、文件、剪贴板三条来源', (tester) async {
    _overridePlatform(TargetPlatform.iOS);
    await _pumpAction(
      tester,
      action: (context, ref) =>
          showMobileImageMetadataImportSheet(context: context, ref: ref),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-metadata-import-photo-library')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-metadata-import-file')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-metadata-import-clipboard')),
      findsOneWidget,
    );
  });

  testWidgets('非 iOS 不出相册来源（系统文件选择器本身就能进相册）', (tester) async {
    _overridePlatform(TargetPlatform.android);
    await _pumpAction(
      tester,
      action: (context, ref) =>
          showMobileImageMetadataImportSheet(context: context, ref: ref),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-metadata-import-photo-library')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mobile-metadata-import-file')),
      findsOneWidget,
    );
  });

  test('相册取图要原始文件：不许系统转码，否则元数据会丢', () async {
    final picker = _RecordingFilePicker();
    _installFilePicker(picker);

    final picked =
        await MobileImageMetadataImporter.pickPhotoLibraryImageBytes();

    expect(picked, isNull);
    expect(picker.type, FileType.image);
    expect(picker.allowCompression, isFalse);
    expect(picker.withData, isTrue);
  });

  testWidgets('取不到图时报告而不是静默返回', (tester) async {
    var reportedNothing = false;
    var processed = false;
    final importer = MobileImageMetadataImporter(
      imageBytesPicker: () async => null,
      imageProcessor: (context, ref, image) async {
        processed = true;
      },
    );

    await _pumpAction(
      tester,
      action: (context, ref) => importer.run(
        context: context,
        ref: ref,
        onNothingPicked: () => reportedNothing = true,
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(reportedNothing, isTrue);
    expect(processed, isFalse);
  });
}

typedef _TestAction =
    Future<Object?> Function(BuildContext context, WidgetRef ref);

Future<void> _pumpAction(
  WidgetTester tester, {
  required _TestAction action,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Consumer(
          builder: (context, ref, child) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => action(context, ref),
              child: const Text('run'),
            ),
          ),
        ),
      ),
    ),
  );
}

void _overridePlatform(TargetPlatform platform) {
  PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
    platform,
  );
  addTearDown(() => PlatformCapabilities.debugOverride = null);
}

void _installFilePicker(FilePicker picker) {
  FilePicker? original;
  try {
    original = FilePicker.platform;
  } catch (_) {
    original = null;
  }
  FilePicker.platform = picker;
  addTearDown(() {
    if (original != null) FilePicker.platform = original;
  });
}

class _RecordingFilePicker extends FilePicker {
  FileType? type;
  bool? allowCompression;
  bool? withData;

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
    this.type = type;
    this.allowCompression = allowCompression;
    this.withData = withData;
    return null;
  }
}
