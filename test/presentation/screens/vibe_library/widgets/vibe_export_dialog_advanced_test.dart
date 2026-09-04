import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog_advanced.dart';

void main() {
  testWidgets('单项导出入口在 320 宽 3x、SafeArea 和 IME 下可取消返回', (tester) async {
    _configureCompactView(tester);
    var completedCount = 0;

    await tester.pumpWidget(
      _wrap(
        _DialogLauncher(
          onOpen: (context) async {
            await VibeExportDialog.show(
              context,
              entries: [_buildEntry(id: 'single', displayName: 'Single')],
              categories: const <VibeLibraryCategory>[],
            );
            completedCount++;
          },
        ),
        textScaler: const TextScaler.linear(3),
      ),
    );

    await tester.tap(find.text('打开导出'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.byKey(const Key('vibe-export-compact-actions')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(completedCount, 1);
    expect(find.byType(VibeExportDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('批量高级导出入口在 320 宽 3x、SafeArea 和 IME 下可取消回调', (tester) async {
    _configureCompactView(tester);
    var completedCount = 0;

    await tester.pumpWidget(
      _wrap(
        _DialogLauncher(
          onOpen: (context) async {
            await VibeExportDialogAdvanced.show(
              context,
              entries: [
                _buildEntry(id: 'first', displayName: 'First'),
                _buildEntry(id: 'second', displayName: 'Second'),
              ],
            );
            completedCount++;
          },
        ),
        textScaler: const TextScaler.linear(3),
      ),
    );

    await tester.tap(find.text('打开导出'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.byKey(const Key('vibe-export-advanced-compact-actions')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(completedCount, 1);
    expect(find.byType(VibeExportDialogAdvanced), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (width, surfaceKey) in [
    (700.0, 'adaptive-bottom-sheet'),
    (1200.0, 'adaptive-centered-form'),
  ]) {
    testWidgets('${width.toInt()} 宽完整导出管理器使用共享自适应表单', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          _DialogLauncher(
            onOpen: (context) => VibeExportDialogAdvanced.show(
              context,
              entries: [
                _buildEntry(id: 'first', displayName: 'First'),
                _buildEntry(id: 'second', displayName: 'Second'),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开导出'));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey(surfaceKey)), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${width.toInt()} 宽单条导出管理器使用共享自适应表单', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          _DialogLauncher(
            onOpen: (context) => VibeExportDialog.show(
              context,
              entries: [_buildEntry(id: 'single', displayName: 'Single')],
              categories: const <VibeLibraryCategory>[],
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开导出'));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey(surfaceKey)), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('单个 Vibe 的 PNG 导出保留外部 PNG 选择入口', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VibeExportDialogAdvanced(
          entries: [
            _buildEntry(
              id: 'single',
              displayName: 'Single',
              rawImageData: _createInMemoryPngBytes(),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('导出为 PNG'));
    await tester.pumpAndSettle();

    expect(find.text('选择外部 PNG 图片...'), findsOneWidget);
  });

  test('更换载体图片按钮按输入方式切换命中区', () {
    expect(
      vibeExportChangeImageMinimumSize(InteractionPolicy.touchFirst),
      const Size.square(48),
    );
    expect(
      vibeExportChangeImageMinimumSize(
        const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
      ),
      Size.zero,
    );
  });

  testWidgets('批量 PNG 导出不提供嵌入 PNG 入口', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VibeExportDialogAdvanced(
          entries: [
            _buildEntry(
              id: 'first',
              displayName: 'First',
              rawImageData: _createInMemoryPngBytes(),
            ),
            _buildEntry(
              id: 'second',
              displayName: 'Second',
              rawImageData: Uint8List.fromList(
                List<int>.from(_createInMemoryPngBytes()),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('导出为 PNG'), findsNothing);
    expect(find.text('选择外部 PNG 图片...'), findsNothing);
  });
}

void _configureCompactView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  tester.view.viewInsets = const FakeViewPadding(bottom: 260);
  addTearDown(tester.view.reset);
}

class _DialogLauncher extends StatelessWidget {
  const _DialogLauncher({required this.onOpen});

  final Future<void> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => onOpen(context),
      child: const Text('打开导出'),
    );
  }
}

Widget _wrap(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
  InteractionPolicy? interactionPolicy,
}) {
  return ProviderScope(
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('zh'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: InteractionPolicyScope(
          initialPolicy: interactionPolicy,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

VibeLibraryEntry _buildEntry({
  required String id,
  required String displayName,
  Uint8List? rawImageData,
}) {
  return VibeLibraryEntry(
    id: id,
    name: displayName,
    vibeDisplayName: displayName,
    vibeEncoding: 'ZW5jb2RlZA==',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    rawImageData: rawImageData,
    createdAt: DateTime(2026, 4, 14),
  );
}

Uint8List _createInMemoryPngBytes() {
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
  return Uint8List.fromList(base64Decode(base64Png));
}
