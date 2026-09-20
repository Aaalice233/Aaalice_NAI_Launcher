import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog.dart';

/// 「单文件」格式在多选时走的是「先选目录、再逐个写文件」，
/// iOS 上 `FileExportService.pickExportDirectory` 只能返回 null，
/// 上游的写法表现为「选好格式点导出，什么都不发生」。
void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  testWidgets('iOS 多条目导出隐藏单文件格式，保留打包格式', (tester) async {
    await _pumpDialog(tester, TargetPlatform.iOS);

    expect(find.text('单文件 (.naiv4vibe)'), findsNothing);
    expect(find.text('打包文件 (.naiv4vibebundle)'), findsOneWidget);
  });

  testWidgets('桌面端多条目导出仍提供单文件格式', (tester) async {
    await _pumpDialog(tester, TargetPlatform.windows);

    expect(find.text('单文件 (.naiv4vibe)'), findsOneWidget);
    expect(find.text('打包文件 (.naiv4vibebundle)'), findsOneWidget);
  });
}

Future<void> _pumpDialog(WidgetTester tester, TargetPlatform platform) async {
  PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
    platform,
  );
  // 给足高度，避免对话框内容在默认 800x600 表面上溢出而把断言淹没在 overflow 里。
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VibeExportDialog(
            entries: [
              _buildEntry(id: 'first', displayName: 'First'),
              _buildEntry(id: 'second', displayName: 'Second'),
            ],
            categories: const <VibeLibraryCategory>[],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

VibeLibraryEntry _buildEntry({
  required String id,
  required String displayName,
}) {
  return VibeLibraryEntry(
    id: id,
    name: displayName,
    vibeDisplayName: displayName,
    vibeEncoding: 'ZW5jb2RlZA==',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    createdAt: DateTime(2026, 4, 14),
  );
}
