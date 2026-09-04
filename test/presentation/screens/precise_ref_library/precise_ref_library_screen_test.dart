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
import 'package:nai_launcher/presentation/providers/precise_ref_library_selection_provider.dart';
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

class _PopulatedLibraryNotifier extends PreciseRefLibraryNotifier {
  static final entries = [
    PreciseRefLibraryEntry(
      id: 'first',
      name: '第一项',
      imagePath: 'first.png',
      createdAt: DateTime(2026),
    ),
    PreciseRefLibraryEntry(
      id: 'second',
      name: '第二项',
      imagePath: 'second.png',
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  @override
  PreciseRefLibraryState build() =>
      PreciseRefLibraryState(entries: entries, filteredEntries: entries);

  @override
  Future<void> initialize() async {}
}

class _ThumbnailFreeStorage extends PreciseRefLibraryStorageService {
  @override
  Uint8List? peekDisplayThumbnail(String id) => null;

  @override
  Future<Uint8List?> getDisplayThumbnail(
    String id, {
    bool Function()? isCancelled,
  }) async => null;
}

void main() {
  testWidgets('空库仍保留公共顶栏导入能力与中央主操作', (tester) async {
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
      findsOneWidget,
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

  testWidgets('精准参考顶栏进入多选，卡片点击切换且系统返回先退出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preciseRefLibraryNotifierProvider.overrideWith(
            _PopulatedLibraryNotifier.new,
          ),
          preciseRefLibraryStorageServiceProvider.overrideWithValue(
            _ThumbnailFreeStorage(),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PreciseRefLibraryScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('precise-ref-library-multi-select-button')),
    );
    await tester.pump();
    expect(find.text('已选择 0 项'), findsOneWidget);

    await tester.tap(find.text('第一项'));
    await tester.pump();
    expect(
      container.read(preciseRefLibrarySelectionNotifierProvider).selectedIds,
      {'first'},
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      container.read(preciseRefLibrarySelectionNotifierProvider).isActive,
      isFalse,
    );
    expect(find.text('精准参考库'), findsOneWidget);
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
