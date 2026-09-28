import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_category_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_screen.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart';

void main() {
  for (final status in [AuthStatus.unauthenticated, AuthStatus.loading]) {
    testWidgets('Vibe Library 真实图片导入在 $status 时不开始编码', (tester) async {
      final paramsNotifier = _RecordingGenerationParamsNotifier();
      final storage = _RecordingVibeLibraryStorageService();
      final container = _createContainer(
        status: status,
        paramsNotifier: paramsNotifier,
        storage: storage,
      );
      addTearDown(container.dispose);

      await _pumpLibrary(tester, container);
      await _startRawImageImport(tester);

      expect(find.byType(VibeImageEncodeDialog), findsOneWidget);
      await _tapEncodeConfirm(tester);
      await tester.pumpAndSettle();

      expect(paramsNotifier.encodeCalls, 0);
      expect(storage.saveCalls, 0);
      expect(find.byType(VibeImageEncodeDialog), findsNothing);
      expect(find.text('正在导入...'), findsNothing);
      expect(
        container.read(authPromptRequestProvider)?.reason,
        AuthPromptReason.vibeEncoding,
      );
    });
  }

  testWidgets('V3 原图导入无需联网并允许匿名保存', (tester) async {
    final paramsNotifier = _RecordingGenerationParamsNotifier(
      model: ImageModels.animeDiffusionV3,
    );
    final storage = _RecordingVibeLibraryStorageService();
    final container = _createContainer(
      status: AuthStatus.unauthenticated,
      paramsNotifier: paramsNotifier,
      storage: storage,
    );
    addTearDown(container.dispose);

    await _pumpLibrary(tester, container);
    await _startRawImageImport(tester);
    await _tapEncodeConfirm(tester);
    await tester.pumpAndSettle();

    expect(paramsNotifier.encodeCalls, 0);
    expect(storage.saveCalls, 1);
    expect(container.read(authPromptRequestProvider), isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Vibe Library 登录后保留导入并立即编码路径', (tester) async {
    final paramsNotifier = _RecordingGenerationParamsNotifier();
    final storage = _RecordingVibeLibraryStorageService();
    final container = _createContainer(
      status: AuthStatus.authenticated,
      paramsNotifier: paramsNotifier,
      storage: storage,
    );
    addTearDown(container.dispose);

    await _pumpLibrary(tester, container);
    await _startRawImageImport(tester);
    await _tapEncodeConfirm(tester);
    await tester.pumpAndSettle();

    expect(paramsNotifier.encodeCalls, 1);
    expect(storage.saveCalls, 1);
    expect(container.read(authPromptRequestProvider), isNull);
    expect(find.text('正在导入...'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}

ProviderContainer _createContainer({
  required AuthStatus status,
  required _RecordingGenerationParamsNotifier paramsNotifier,
  required _RecordingVibeLibraryStorageService storage,
}) {
  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _TestAuthNotifier(status)),
      generationParamsNotifierProvider.overrideWith(() => paramsNotifier),
      vibeLibraryNotifierProvider.overrideWith(_TestVibeLibraryNotifier.new),
      vibeLibraryCategoryNotifierProvider.overrideWith(
        _TestVibeLibraryCategoryNotifier.new,
      ),
      vibeLibraryStorageServiceProvider.overrideWithValue(storage),
    ],
  );
}

Future<void> _pumpLibrary(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final imageBytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 2, height: 2)),
  );
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VibeLibraryScreen(
          pickImportFiles: () async => [
            PlatformFile(
              name: 'raw-vibe.png',
              size: imageBytes.length,
              bytes: imageBytes,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapEncodeConfirm(WidgetTester tester) async {
  final confirm = find.descendant(
    of: find.byType(VibeImageEncodeDialog),
    matching: find.byType(FilledButton),
  );
  await tester.ensureVisible(confirm);
  await tester.pump();
  await tester.tap(confirm);
}

Future<void> _startRawImageImport(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('vibe-library-empty-import')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 6));
  await tester.pump();
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.authStatus);

  final AuthStatus authStatus;

  @override
  AuthState build() => AuthState(status: authStatus);
}

class _RecordingGenerationParamsNotifier extends GenerationParamsNotifier {
  _RecordingGenerationParamsNotifier({
    this.model = ImageModels.animeDiffusionV45Full,
  });

  final String model;
  int encodeCalls = 0;

  @override
  ImageParams build() => ImageParams(model: model);

  @override
  bool hasCachedVibeEncoding(
    Uint8List imageData, {
    required String model,
    double informationExtracted = 1.0,
  }) => false;

  @override
  Future<String?> encodeVibeWithCache(
    Uint8List imageData, {
    required String model,
    double informationExtracted = 1.0,
    String? vibeName,
  }) async {
    encodeCalls++;
    return 'encoded-vibe';
  }
}

class _TestVibeLibraryNotifier extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() => const VibeLibraryState();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadFromCache({bool showLoading = false}) async {}
}

class _TestVibeLibraryCategoryNotifier extends VibeLibraryCategoryNotifier {
  @override
  VibeLibraryCategoryState build() => const VibeLibraryCategoryState();
}

class _RecordingVibeLibraryStorageService extends VibeLibraryStorageService {
  int saveCalls = 0;

  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    saveCalls++;
    return entry;
  }
}
