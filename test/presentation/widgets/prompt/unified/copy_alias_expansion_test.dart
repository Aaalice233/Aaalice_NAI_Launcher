import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

const _entryName = 'scenery';
const _entryContent = 'forest, sunlight, wind';
const _promptText = 'masterpiece, <$_entryName>, best quality';
const _expandedText = 'masterpiece, $_entryContent, best quality';

/// 复制/剪切时展开 `<词库名>` 的回归测试
///
/// 覆盖键盘（Ctrl+C / Ctrl+X）与右键菜单两条独立路径，
/// 二者共用 `_handleExpandedClipboardAction`。
void main() {
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
  });

  /// Windows 平台下运行测试体
  ///
  /// `debugDefaultTargetPlatformOverride` 必须在测试体内还原：
  /// flutter_test 在 tearDown 之前就会校验 foundation 调试变量。
  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// 读取最后一次写入剪贴板的文本
  String? lastClipboardText() {
    final setDataCalls = platformCalls
        .where((call) => call.method == 'Clipboard.setData')
        .toList();
    if (setDataCalls.isEmpty) return null;
    return (setDataCalls.last.arguments as Map)['text'] as String?;
  }

  /// 剪贴板写入次数
  ///
  /// 必须恒为 1：Windows 剪贴板是独占资源，紧挨着的第二次写入可能静默失败，
  /// 留下未展开的原文。mock 的 platform channel 不会复现这种失败，
  /// 所以只能靠这条断言守住"只写一次"。
  int clipboardWriteCount() =>
      platformCalls.where((call) => call.method == 'Clipboard.setData').length;

  Future<void> pumpInput(
    WidgetTester tester, {
    required bool resolveAliasOnCopy,
    bool enableTagMode = false,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': ''};
        }
        if (call.method == 'Clipboard.hasStrings') {
          return <String, dynamic>{'value': true};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(
              resolveAliasOnCopy: resolveAliasOnCopy,
            ),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 120,
              child: UnifiedPromptInput(
                enableAssistant: false,
                config: UnifiedPromptConfig(
                  enableTagMode: enableTagMode,
                  enableAutocomplete: false,
                  enableSyntaxHighlight: false,
                  enableAutoFormat: false,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 输入提示词、全选，并触发 Ctrl+C 或 Ctrl+X
  Future<void> selectAllAndPress(
    WidgetTester tester,
    LogicalKeyboardKey key,
  ) async {
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, _promptText);
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: _promptText.length,
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('开关打开时 Ctrl+C 复制展开后的词库内容', (tester) async {
    await onWindows(() async {
      await pumpInput(tester, resolveAliasOnCopy: true);
      await selectAllAndPress(tester, LogicalKeyboardKey.keyC);

      expect(lastClipboardText(), _expandedText);
      expect(clipboardWriteCount(), 1);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets('隐藏禁用语法后复制仍保留禁用状态且只写一次剪贴板', (tester) async {
    await onWindows(() async {
      await pumpInput(tester, resolveAliasOnCopy: false, enableTagMode: true);
      const raw = 'cat, /*disabled:dog*/, bird';
      await tester.enterText(find.byType(TextField), raw);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, 'cat, dog, bird');
      editable.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: editable.controller.text.length,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(lastClipboardText(), raw);
      expect(clipboardWriteCount(), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
  testWidgets('复制展开别名时仍保留禁用标记及其原始内容', (tester) async {
    await onWindows(() async {
      await pumpInput(tester, resolveAliasOnCopy: true);
      const text = '<scenery>, /*disabled:<scenery>*/';
      final field = find.byType(TextField);
      await tester.enterText(field, text);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(lastClipboardText(), '$_entryContent, /*disabled:<scenery>*/');
      expect(clipboardWriteCount(), 1);
    });
  });

  testWidgets('开关关闭时 Ctrl+C 保持原始别名文本', (tester) async {
    await onWindows(() async {
      await pumpInput(tester, resolveAliasOnCopy: false);
      await selectAllAndPress(tester, LogicalKeyboardKey.keyC);

      expect(lastClipboardText(), _promptText);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('开关打开时 Ctrl+X 同样展开且仍会清空输入框', (tester) async {
    await onWindows(() async {
      await pumpInput(tester, resolveAliasOnCopy: true);
      await selectAllAndPress(tester, LogicalKeyboardKey.keyX);

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(lastClipboardText(), _expandedText);
      expect(clipboardWriteCount(), 1);
      expect(editable.controller.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('开关打开时右键菜单的复制同样展开', (tester) async {
    await onWindows(() async {
      await pumpInput(tester, resolveAliasOnCopy: true);

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, _promptText);
      await tester.pump();

      final editableState = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      editableState.widget.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: _promptText.length,
      );
      await tester.pump();

      editableState.showToolbar();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(lastClipboardText(), _expandedText);
      expect(clipboardWriteCount(), 1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('选区不含别名时不额外写入剪贴板', (tester) async {
    await onWindows(() async {
      await pumpInput(tester, resolveAliasOnCopy: true);

      const plainText = 'masterpiece, best quality';
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, plainText);
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: plainText.length,
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(clipboardWriteCount(), 1);
      expect(lastClipboardText(), plainText);
    });
  });
}

class _TestLocalStorageService extends LocalStorageService {
  _TestLocalStorageService({required this.resolveAliasOnCopy});

  final bool resolveAliasOnCopy;

  @override
  bool getResolveAliasOnCopy() => resolveAliasOnCopy;

  @override
  bool getEnablePromptWeightScroll() => false;

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getAutoFormatPrompt() => false;

  @override
  bool getHighlightEmphasis() => false;

  @override
  bool getSdSyntaxAutoConvert() => false;

  @override
  bool getEnableCooccurrenceRecommendation() => false;

  @override
  String? getTagLibraryEntriesJson() {
    final entry = TagLibraryEntry.create(
      name: _entryName,
      content: _entryContent,
    );
    return jsonEncode([entry.toJson()]);
  }

  @override
  String? getTagLibraryCategoriesJson() => null;

  @override
  int getTagLibraryViewMode() => 0;
}
