import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_provider.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/precise_ref_library_screen.dart';
import 'package:nai_launcher/presentation/utils/precise_ref_library_import_helper.dart';

class _EmptyLibraryNotifier extends PreciseRefLibraryNotifier {
  @override
  PreciseRefLibraryState build() => const PreciseRefLibraryState();

  @override
  Future<void> initialize() async {}
}

class _FailingStorage extends PreciseRefLibraryStorageService {
  @override
  Future<List<PreciseRefLibraryEntry>> getAllEntries() {
    throw const FileSystemException('access denied');
  }

  @override
  Future<PreciseRefLibraryEntry> importFromBytes(
    Uint8List bytes, {
    required String name,
    PreciseRefType type = PreciseRefType.characterAndStyle,
    double strength = 1.0,
    double fidelity = 1.0,
  }) {
    throw const FileSystemException('disk full');
  }
}

void main() {
  testWidgets('空库只保留中央导入主操作，避免工具栏重复入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preciseRefLibraryNotifierProvider.overrideWith(
            _EmptyLibraryNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PreciseRefLibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('precise-ref-library-empty-import-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('precise-ref-library-import-button')),
      findsNothing,
    );
    expect(find.text('导入图片建立参考库'), findsOneWidget);
    expect(find.textContaining('右键'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载失败时显示错误与重试入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preciseRefLibraryStorageServiceProvider.overrideWithValue(
            _FailingStorage(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PreciseRefLibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('加载精准参考库失败'), findsOneWidget);
    expect(find.byKey(const Key('precise-ref-library-retry')), findsOneWidget);
  });

  testWidgets('快捷保存失败时显示错误提示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preciseRefLibraryStorageServiceProvider.overrideWithValue(
            _FailingStorage(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) => TextButton(
                onPressed: () => saveBytesToPreciseRefLibrary(
                  ref,
                  context,
                  Uint8List.fromList([1, 2, 3]),
                ),
                child: const Text('保存'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.textContaining('保存到精准参考库失败'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
