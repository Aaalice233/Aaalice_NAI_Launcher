import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/core/comfyui/builtin_workflows.dart';
import 'package:nai_launcher/core/comfyui/comfyui_url_utils.dart';
import 'package:nai_launcher/core/comfyui/seedvr2_support.dart';
import 'package:nai_launcher/core/comfyui/workflow_node_validator.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_providers.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/comfyui/workflow_template_manager.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/file_explorer_utils.dart';
import 'package:nai_launcher/core/utils/nai_resolution_adapter.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/tag/local_tag.dart';
import 'package:nai_launcher/data/models/tag/tag_suggestion.dart'
    hide TagCategory;
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_service.dart';
import 'package:nai_launcher/data/services/statistics_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/danbooru_suggestion_provider.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/providers/share_image_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_history_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_api_client.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/dashboard/aspect_ratio_card.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog_advanced.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_category_tree_view.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_gallery_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_config.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_utils.dart';
import 'package:nai_launcher/presentation/widgets/metadata/metadata_import_dialog.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_aware_widget.dart';

class _MockDio extends Mock implements Dio {}

class _MockLocalStorageService extends Mock implements LocalStorageService {}

/// 简单的 Widget 测试示例
///
/// 运行: flutter test test/app_test.dart
void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  group('Widget Tests', () {
    testWidgets('MaterialApp 创建', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Hello'))),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('按钮点击', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () => pressed = true,
              child: const Text('Click'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('AppBootstrapEffects 监听 provider 变化时不重建子树', (tester) async {
      final anlasWatcherProvider = StateProvider<int>((ref) => 0);
      final kritaBridgeProvider = StateProvider<int>((ref) => 0);
      final cooccurrenceDataPackProvider = StateProvider<int>((ref) => 0);
      var buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppBootstrapEffects(
              anlasWatcher: anlasWatcherProvider,
              kritaBridge: kritaBridgeProvider,
              cooccurrenceDataPack: cooccurrenceDataPackProvider,
              cloudSyncLifecycle: () async {},
              child: Builder(
                builder: (context) {
                  buildCount++;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppBootstrapEffects)),
      );

      expect(container.exists(anlasWatcherProvider), isTrue);
      expect(container.exists(kritaBridgeProvider), isTrue);
      expect(container.exists(cooccurrenceDataPackProvider), isTrue);
      expect(buildCount, 1);

      container.read(anlasWatcherProvider.notifier).state = 1;
      await tester.pump();
      container.read(kritaBridgeProvider.notifier).state = 1;
      await tester.pump();
      container.read(cooccurrenceDataPackProvider.notifier).state = 1;
      await tester.pump();

      expect(buildCount, 1);
    });

    testWidgets('AppBootstrapEffects 在启动和 resumed 恢复云备份连接', (tester) async {
      var calls = 0;
      final inert = StateProvider<int>((ref) => 0);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppBootstrapEffects(
              anlasWatcher: inert,
              kritaBridge: inert,
              cooccurrenceDataPack: inert,
              cloudSyncLifecycle: () async {
                calls++;
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('云备份连接恢复未完成时跳过重复 resumed', (tester) async {
      final release = Completer<void>();
      var calls = 0;
      final inert = StateProvider<int>((ref) => 0);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppBootstrapEffects(
              anlasWatcher: inert,
              kritaBridge: inert,
              cooccurrenceDataPack: inert,
              cloudSyncLifecycle: () async {
                calls++;
                await release.future;
              },
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 1);
      release.complete();
      await tester.pump();
    });

    testWidgets('本地画廊搜索框 Ctrl+A 应选择文本而不是进入多选', (tester) async {
      var enteredSelectionMode = false;
      const query = 'a';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localGalleryNotifierProvider.overrideWith(
              _FakeLocalGalleryNotifier.new,
            ),
            shortcutConfigNotifierProvider.overrideWith(
              _FakeShortcutConfigNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PageShortcuts(
                contextType: ShortcutContext.gallery,
                shortcuts: {
                  ShortcutIds.enterSelectionMode: () {
                    enteredSelectionMode = true;
                  },
                },
                child: const LocalGalleryToolbar(
                  enableSearchAutocomplete: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.enterText(textField, query);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.selection.baseOffset, 0);
      expect(editable.controller.selection.extentOffset, query.length);
      expect(enteredSelectionMode, isFalse);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(LocalGalleryToolbar)),
      );
      expect(
        container.read(localGallerySelectionNotifierProvider).isActive,
        isFalse,
      );
    });

    testWidgets('本地画廊分类树应分开显示总数和收藏数', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 260,
                height: 200,
                child: GalleryCategoryTreeView(
                  categories: const [],
                  totalImageCount: 42,
                  favoriteCount: 17,
                  selectedCategoryId: 'favorites',
                  onCategorySelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('全部图片'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('词库工具栏重建时搜索框应显示当前搜索条件', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagLibraryPageNotifierProvider.overrideWith(
              _FakeTagLibraryPageNotifier.new,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TagLibraryToolbar()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, 'rabbit');
    });

    testWidgets('词库搜索框 Ctrl+A 应选择文本而不是触发词条全选', (tester) async {
      var selectedAllTags = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagLibraryPageNotifierProvider.overrideWith(
              _FakeTagLibraryPageNotifier.new,
            ),
            shortcutConfigNotifierProvider.overrideWith(
              _FakeShortcutConfigNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PageShortcuts(
                contextType: ShortcutContext.tagLibrary,
                shortcuts: {
                  ShortcutIds.selectAllTags: () {
                    selectedAllTags = true;
                  },
                },
                child: const TagLibraryToolbar(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.selection.baseOffset, 0);
      expect(editable.controller.selection.extentOffset, 'rabbit'.length);
      expect(selectedAllTags, isFalse);
    });

    testWidgets('批量 Vibe 导出不显示嵌入 PNG 入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: VibeExportDialogAdvanced(
                entries: [
                  _buildVibeEntry(id: 'first', displayName: 'First'),
                  _buildVibeEntry(id: 'second', displayName: 'Second'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('导出为 PNG'), findsNothing);
    });

    testWidgets('单个 Vibe 导出显示嵌入 PNG 入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: VibeExportDialog(
                entries: [_buildVibeEntry(id: 'single', displayName: 'Single')],
                categories: const [],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('嵌入到 PNG'), findsOneWidget);

      await tester.tap(find.text('嵌入到 PNG'));
      await tester.pumpAndSettle();

      expect(find.text('选择外部 PNG 图片...'), findsOneWidget);
    });

    testWidgets('元数据导入模型选项应和其他参数一样只显示字段名', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(
              body: MetadataImportDialog(
                metadata: NaiImageMetadata(
                  source: 'NovelAI Diffusion V4.5 4BDE2A90',
                  seed: 1,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('模型'), findsOneWidget);
      expect(find.textContaining('NAI Diffusion V4.5'), findsNothing);
      expect(
        find.textContaining(ImageModels.animeDiffusionV45Full),
        findsNothing,
      );
    });
  });

  group('Online gallery search filters', () {
    test('keeps plain tags exact when fuzzy matching is disabled', () {
      expect(
        buildOnlineGallerySearchQuery('kanzarin', fuzzyMatch: false),
        'kanzarin',
      );
    });

    test('wraps plain tags with wildcards when fuzzy matching is enabled', () {
      expect(
        buildOnlineGallerySearchQuery('kanzarin', fuzzyMatch: true),
        '*kanzarin*',
      );
    });

    test('keeps special Danbooru syntax unchanged in fuzzy mode', () {
      expect(
        buildOnlineGallerySearchQuery(
          'rating:g, order:score, -comic, *kanzarin*',
          fuzzyMatch: true,
        ),
        'rating:g order:score -comic *kanzarin*',
      );
    });

    test('converts comma separated tags to Danbooru AND syntax', () {
      expect(
        buildOnlineGallerySearchQuery(
          'kanzarin, 1girl，solo',
          fuzzyMatch: false,
        ),
        'kanzarin 1girl solo',
      );
    });

    test('treats spaces as tag separators in fuzzy searches', () {
      expect(
        buildOnlineGallerySearchQuery('foot_focus lo', fuzzyMatch: true),
        '*foot_focus* *lo*',
      );
    });

    testWidgets('updates autocomplete for a space separated second tag', (
      tester,
    ) async {
      await _pumpOnlineGalleryScreen(tester);
      await tester.pump();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search tags...',
      );

      await tester.tap(searchField);
      await tester.enterText(searchField, 'foot_focus');
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.byKey(const ValueKey('autocomplete-candidate-foot_focus')),
        findsOneWidget,
      );

      await tester.enterText(searchField, 'foot_focus lo');
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.byKey(const ValueKey('autocomplete-candidate-long_hair')),
        findsOneWidget,
      );
    });

    testWidgets('shows a fuzzy matching toggle in the search toolbar', (
      tester,
    ) async {
      await _pumpOnlineGalleryScreen(tester);
      await tester.pump();

      expect(find.text('Fuzzy Match'), findsOneWidget);
    });

    testWidgets('opens date range controls in a compact anchored popup', (
      tester,
    ) async {
      await _pumpOnlineGalleryScreen(tester);
      await tester.pump();

      await tester.tap(find.text('Date Range'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });
  });

  group('AutocompleteWrapper', () {
    test('preserves prompt syntax wrappers when applying a tag suggestion', () {
      const suggestion = LocalTag(tag: 'raiden_shogun');
      const config = AutocompleteConfig(autoInsertComma: true);

      (String, int) apply(String text, int cursorPosition) {
        return AutocompleteUtils.applySuggestion(
          text: text,
          cursorPosition: cursorPosition,
          suggestion: suggestion,
          config: config,
        );
      }

      expect(apply('{rai}', 4).$1, '{raiden_shogun}, ');
      expect(apply('{rai}', 5).$1, '{raiden_shogun}, ');
      expect(apply('[rai]', 4).$1, '[raiden_shogun], ');
      expect(apply('[rai]', 5).$1, '[raiden_shogun], ');
      expect(apply('(rai)', 4).$1, '(raiden_shogun), ');
      expect(apply('(rai)', 5).$1, '(raiden_shogun), ');
      expect(apply('{{rai}}', 5).$1, '{{raiden_shogun}}, ');
      expect(apply('{{rai}}', 7).$1, '{{raiden_shogun}}, ');
      expect(apply('{2::rai::}', 10).$1, '{2::raiden_shogun::}, ');
      expect(apply('{2::rai}', 8).$1, '{2::raiden_shogun::}, ');
      expect(apply('2::rai::', 6).$1, '2::raiden_shogun::, ');
      expect(apply('2::rai ::', 6).$1, '2::raiden_shogun::, ');
      expect(apply('2::rai', 6).$1, '2::raiden_shogun::, ');
      expect(apply('rai::', 3).$1, 'raiden_shogun::, ');
      expect(apply('2::{rai}::', 7).$1, '2::{raiden_shogun}::, ');
      expect(apply('2::{rai}::', 10).$1, '2::{raiden_shogun}::, ');
    });

    testWidgets('keeps wrappers through the unified prompt input stack', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autocompleteLocalSourcesProvider.overrideWithValue(const [
              _FakeCompletionSource(),
            ]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 180,
                child: UnifiedPromptInput(
                  controller: controller,
                  focusNode: focusNode,
                  enableAssistant: false,
                  config: const UnifiedPromptConfig(
                    enableAutocomplete: true,
                    enableSyntaxHighlight: true,
                    enableAutoFormat: true,
                    autocompleteConfig: AutocompleteConfig(
                      autoInsertComma: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '{rai}');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      final candidate = find.byKey(
        const ValueKey('autocomplete-candidate-raiden_shogun'),
      );
      expect(candidate, findsOneWidget);

      await tester.tap(candidate);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(controller.text, '{raiden_shogun}, ');
      expect(candidate, findsNothing);
    });
  });

  group('ComfyUI URL helpers', () {
    test('normalizes pasted server URLs without breaking scheme typing', () {
      expect(
        normalizeComfyUIBaseUrl('  http://127.0.0.1:8188/  '),
        'http://127.0.0.1:8188',
      );
      expect(
        normalizeComfyUIBaseUrl('https://example.test/comfyui///'),
        'https://example.test/comfyui',
      );
      expect(normalizeComfyUIBaseUrl('http://'), 'http://');
      expect(normalizeComfyUIBaseUrl('https://'), 'https://');
    });

    test('builds websocket URLs without double slashes', () {
      final rootUri = buildComfyUIWebSocketUri(
        baseUrl: 'http://127.0.0.1:8188/',
        clientId: 'client-1',
      );
      final proxiedUri = buildComfyUIWebSocketUri(
        baseUrl: 'https://example.test/comfyui/',
        clientId: 'client-1',
      );

      expect(rootUri.toString(), 'ws://127.0.0.1:8188/ws?clientId=client-1');
      expect(
        proxiedUri.toString(),
        'wss://example.test/comfyui/ws?clientId=client-1',
      );
    });
  });

  group('File explorer helpers', () {
    test('keeps a split Explorer select fallback for paths with spaces', () {
      const filePath = r'C:\Users\alice\NAI Launcher\history image.png';

      expect(FileExplorerUtils.windowsRevealFileArguments(filePath), [
        '/select,',
        filePath,
      ]);
    });

    test('normalizes extended-length drive paths for Windows Explorer', () {
      expect(
        FileExplorerUtils.normalizeWindowsExplorerPath(
          r'\\?\C:\Users\alice\NAI Launcher\history image.png',
        ),
        r'C:\Users\alice\NAI Launcher\history image.png',
      );
    });

    test('normalizes extended-length UNC paths for Windows Explorer', () {
      expect(
        FileExplorerUtils.normalizeWindowsExplorerPath(
          r'\\?\UNC\nas\gallery\history image.png',
        ),
        r'\\nas\gallery\history image.png',
      );
    });

    test('reveals existing files through the shared launcher path', () async {
      final tempDir = await Directory.systemTemp.createTemp('nai_reveal_test_');
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}history image.png',
      );
      await file.writeAsString('image');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      String? executable;
      List<String>? arguments;

      await FileExplorerUtils.revealFile(
        file.path,
        startProcess: (exe, args) async {
          executable = exe;
          arguments = List<String>.of(args);
        },
      );

      final absolutePath = Platform.isWindows
          ? FileExplorerUtils.normalizeWindowsExplorerPath(file.absolute.path)
          : file.absolute.path;

      if (Platform.isWindows) {
        expect(executable, 'explorer.exe');
        expect(
          arguments,
          FileExplorerUtils.windowsRevealFileArguments(absolutePath),
        );
      } else if (Platform.isMacOS) {
        expect(executable, 'open');
        expect(arguments, ['-R', absolutePath]);
      } else if (Platform.isLinux) {
        expect(executable, 'xdg-open');
        expect(arguments, [file.parent.absolute.path]);
      }
    });
  });

  group('ComfyUI upscale workflows', () {
    test('native SeedVR2 workflow uses the ComfyUI core node graph', () {
      final workflow = BuiltinWorkflows.all.firstWhere(
        (workflow) => workflow.id == comfySeedvr2NativeUpscaleTemplateId,
      );
      final nodeTypes = extractWorkflowNodeTypes(workflow.workflowJson);

      expect(
        nodeTypes,
        containsAll([
          'SeedVR2Preprocess',
          'SeedVR2Conditioning',
          'SeedVR2PostProcessing',
          'KSampler',
        ]),
      );
      expect(nodeTypes, isNot(contains('SeedVR2VideoUpscaler')));
      expect(nodeTypes, isNot(contains('SeedVR2LoadDiTModel')));
      expect(nodeTypes, isNot(contains('SeedVR2LoadVAEModel')));
      expect(workflow.workflowJson['9']['inputs']['steps'], 1);
      expect(workflow.workflowJson['9']['inputs']['cfg'], 1.0);
      expect(workflow.workflowJson['9']['inputs']['sampler_name'], 'euler');
      expect(workflow.workflowJson['9']['inputs']['scheduler'], 'simple');
    });

    test('injects native SeedVR2 model, VAE, scale, tiles, and seed', () {
      final manager = WorkflowTemplateManager()..loadBuiltinTemplates();
      final workflow = manager.getById(comfySeedvr2NativeUpscaleTemplateId)!;

      final executable = manager.buildExecutableWorkflow(
        template: workflow,
        paramValues: const {
          'scale': 1.75,
          'dit_model': 'seedvr2_7b_sharp_int8_convrot.safetensors',
          'vae_model': 'ema_vae_fp16.safetensors',
          'vae_encode_tile_size': 768,
          'vae_decode_tile_size': 768,
          'seed': 1234,
        },
      );

      expect(executable['3']['inputs']['scale_by'], 1.75);
      expect(
        executable['7']['inputs']['unet_name'],
        'seedvr2_7b_sharp_int8_convrot.safetensors',
      );
      expect(executable['5']['inputs']['vae_name'], 'ema_vae_fp16.safetensors');
      expect(executable['6']['inputs']['tile_size'], 768);
      expect(executable['10']['inputs']['tile_size'], 768);
      expect(executable['9']['inputs']['seed'], 1234);
    });

    test('legacy SeedVR2 workflow avoids optional helper nodes', () {
      final workflow = BuiltinWorkflows.all.firstWhere(
        (workflow) => workflow.id == comfySeedvr2LegacyUpscaleTemplateId,
      );
      final nodeTypes = extractWorkflowNodeTypes(workflow.workflowJson);

      expect(nodeTypes, isNot(contains('Float')));
      expect(nodeTypes, isNot(contains('easy imageSizeBySide')));
      expect(nodeTypes, isNot(contains('LayerUtility: NumberCalculatorV2')));
      expect(workflow.workflowJson['5']['inputs']['resolution'], isA<int>());
      expect(
        workflow.parameterSlots.map((slot) => slot.id),
        contains('target_resolution'),
      );
    });

    test('injects SeedVR2 target resolution into the upscaler node', () {
      final manager = WorkflowTemplateManager()..loadBuiltinTemplates();
      final workflow = manager.getById(comfySeedvr2LegacyUpscaleTemplateId)!;

      final executable = manager.buildExecutableWorkflow(
        template: workflow,
        paramValues: const {'target_resolution': 1536},
      );

      expect(executable['5']['inputs']['resolution'], 1536);
    });

    test('injects SeedVR2 VAE tile size into encode and decode fields', () {
      final manager = WorkflowTemplateManager()..loadBuiltinTemplates();
      final workflow = manager.getById(comfySeedvr2LegacyUpscaleTemplateId)!;

      final executable = manager.buildExecutableWorkflow(
        template: workflow,
        paramValues: const {
          'vae_encode_tile_size': 768,
          'vae_decode_tile_size': 768,
        },
      );

      expect(executable['7']['inputs']['encode_tile_size'], 768);
      expect(executable['7']['inputs']['decode_tile_size'], 768);
    });

    test('injects SeedVR2 block swap settings into the DiT loader node', () {
      final manager = WorkflowTemplateManager()..loadBuiltinTemplates();
      final workflow = manager.getById(comfySeedvr2LegacyUpscaleTemplateId)!;

      final executable = manager.buildExecutableWorkflow(
        template: workflow,
        paramValues: const {'blocks_to_swap': 28, 'swap_io_components': true},
      );

      expect(executable['6']['inputs']['blocks_to_swap'], 28);
      expect(executable['6']['inputs']['swap_io_components'], isTrue);
      // sageattn / flash_attn 需要额外安装，发行默认值必须是 PyTorch 内置后端。
      expect(executable['6']['inputs']['attention_mode'], 'sdpa');
    });

    test('injects SeedVR2 block swap settings into the tiled workflow', () {
      final manager = WorkflowTemplateManager()..loadBuiltinTemplates();
      final workflow = manager.getById(
        comfySeedvr2LegacyTiledUpscaleTemplateId,
      )!;

      final executable = manager.buildExecutableWorkflow(
        template: workflow,
        paramValues: const {'blocks_to_swap': 0, 'swap_io_components': false},
      );

      expect(executable['6']['inputs']['blocks_to_swap'], 0);
      expect(executable['6']['inputs']['swap_io_components'], isFalse);
    });

    test('includes RTX upscale workflow using Nvidia RTX nodes', () {
      final manager = WorkflowTemplateManager()..loadBuiltinTemplates();
      final workflow = manager.getById('builtin_rtx_upscale')!;
      final nodeTypes = extractWorkflowNodeTypes(workflow.workflowJson);

      expect(nodeTypes, contains('RTXVideoSuperResolution'));
      expect(nodeTypes, isNot(contains('UpscaleModelLoader')));
      expect(
        workflow.parameterSlots.map((slot) => slot.id),
        contains('rtx_scale'),
      );
    });

    test('includes SeedVR2 tiled workflow with tile size controls', () {
      final manager = WorkflowTemplateManager()..loadBuiltinTemplates();
      final workflow = manager.getById('builtin_seedvr2_tiled_upscale')!;

      final executable = manager.buildExecutableWorkflow(
        template: workflow,
        paramValues: const {'tile_size': 1280, 'tile_upscale_resolution': 1536},
      );

      expect(executable['8']['class_type'], 'SeedVR2TilingUpscaler');
      expect(executable['8']['inputs']['tile_width'], 1280);
      expect(executable['8']['inputs']['tile_height'], 1280);
      expect(executable['8']['inputs']['tile_upscale_resolution'], 1536);
      expect(executable['8']['inputs']['resolution_target'], 'longest');
      expect(executable['8']['inputs']['tile_batch_size'], 1);
    });

    test('detects missing ComfyUI node types before queueing workflow', () {
      final missing = findMissingWorkflowNodeTypes(
        workflow: {
          '1': {'class_type': 'LoadImage', 'inputs': <String, dynamic>{}},
          '18': {'class_type': 'Float', 'inputs': <String, dynamic>{}},
        },
        objectInfo: {'LoadImage': <String, dynamic>{}},
      );

      expect(missing, ['Float']);
      expect(formatMissingWorkflowNodeTypesMessage(missing), contains('Float'));
    });

    test('detects required inputs added by updated ComfyUI nodes', () {
      final missing = findMissingWorkflowRequiredInputs(
        workflow: {
          '8': {
            'class_type': 'SeedVR2TilingUpscaler',
            'inputs': {
              'image': ['15', 0],
            },
          },
        },
        objectInfo: {
          'SeedVR2TilingUpscaler': {
            'input': {
              'required': {
                'image': ['IMAGE'],
                'tile_batch_size': ['INT'],
              },
            },
          },
        },
      );

      expect(missing, [
        (
          nodeId: '8',
          nodeType: 'SeedVR2TilingUpscaler',
          inputName: 'tile_batch_size',
        ),
      ]);
      expect(
        formatMissingWorkflowRequiredInputsMessage(missing),
        contains('tile_batch_size'),
      );
    });

    test('calculates SeedVR2 target resolution from source shortest side', () {
      expect(
        calculateComfySeedvr2TargetResolution(
          sourceWidth: 832,
          sourceHeight: 1216,
          scale: 1.5,
        ),
        1248,
      );
    });

    test('adapts img2img sources to 64-pixel grid without preset snapping', () {
      final adapted = NaiResolutionAdapter.findClosestResolution(1000, 1400);

      expect(adapted.width, 1024);
      expect(adapted.height, 1408);
      expect(
        NaiResolutionAdapter.isCompatible(adapted.width, adapted.height),
        isTrue,
      );
    });

    test('does not overwrite saved upscale model before server fetch', () {
      expect(
        shouldAutoPersistResolvedUpscaleModel(
          isComfyBackend: true,
          hasFetchedFromServer: false,
          availableModels: const ['seedvr2_ema_7b_fp16.safetensors'],
          currentModel: 'seedvr2_ema_3b-Q4_K_M.gguf',
          resolvedModel: 'seedvr2_ema_7b_fp16.safetensors',
        ),
        isFalse,
      );
      expect(
        shouldAutoPersistResolvedUpscaleModel(
          isComfyBackend: true,
          hasFetchedFromServer: true,
          availableModels: const ['seedvr2_ema_7b_fp16.safetensors'],
          currentModel: 'missing-model.safetensors',
          resolvedModel: 'seedvr2_ema_7b_fp16.safetensors',
        ),
        isTrue,
      );
    });

    test(
      'includes regular model upscale workflow with Lanczos final resize',
      () {
        final workflow = BuiltinWorkflows.all.firstWhere(
          (workflow) => workflow.id == comfyModelUpscaleTemplateId,
        );

        expect(workflow.workflowJson['2']['class_type'], 'UpscaleModelLoader');
        expect(
          workflow.workflowJson['3']['class_type'],
          'ImageUpscaleWithModel',
        );
        expect(workflow.workflowJson['4']['class_type'], 'ImageScale');
        expect(
          workflow.workflowJson['4']['inputs']['upscale_method'],
          'lanczos',
        );
      },
    );

    test('classifies SeedVR2 and regular ComfyUI upscale models', () {
      expect(
        isComfySeedvr2UpscaleModel('seedvr2_ema_7b_fp16.safetensors'),
        isTrue,
      );
      expect(
        isComfySeedvr2UpscaleModel('4x-UltraSharpV2.safetensors'),
        isFalse,
      );
      expect(
        isComfySeedvr2UpscaleModel('realesrganX4plusAnime_v1.pt'),
        isFalse,
      );
    });
  });

  group('Image workflow upscale persistence', () {
    late Directory hiveTempDir;

    setUpAll(() async {
      hiveTempDir = await Directory.systemTemp.createTemp(
        'nai_launcher_app_test_hive_',
      );
      Hive.init(hiveTempDir.path);
      await Hive.openBox(StorageKeys.settingsBox);
    });

    setUp(() async {
      await Hive.box(StorageKeys.settingsBox).clear();
    });

    tearDownAll(() async {
      if (Hive.isBoxOpen(StorageKeys.settingsBox)) {
        await Hive.box(StorageKeys.settingsBox).close();
      }
      if (await hiveTempDir.exists()) {
        await hiveTempDir.delete(recursive: true);
      }
    });

    test('keeps separate model choices across local upscale engines', () async {
      const nativeSeedvr2Model = 'seedvr2_7b_sharp_int8_convrot.safetensors';
      const legacySeedvr2Model = 'seedvr2_ema_7b_fp16.safetensors';
      const regularModel = '4x-UltraSharpV2.pth';
      final firstContainer = ProviderContainer();

      try {
        final controller = firstContainer.read(
          imageWorkflowControllerProvider.notifier,
        );

        controller.updateComfyUpscaleModule(ComfyUpscaleModule.seedvr2);
        controller.updateSeedvr2Engine(ComfySeedvr2Engine.native);
        controller.updateUpscaleComfyModel(
          nativeSeedvr2Model,
          seedvr2Backend: ComfySeedvr2Backend.native,
        );
        controller.updateSeedvr2Engine(ComfySeedvr2Engine.legacy);
        controller.updateUpscaleComfyModel(
          legacySeedvr2Model,
          seedvr2Backend: ComfySeedvr2Backend.legacy,
        );
        controller.updateComfyUpscaleModule(ComfyUpscaleModule.regular);
        controller.updateUpscaleComfyModel(regularModel);
        controller.updateComfyUpscaleModule(ComfyUpscaleModule.rtx);
        controller.updateComfyUpscaleModule(ComfyUpscaleModule.seedvr2);

        expect(
          firstContainer
              .read(imageWorkflowControllerProvider)
              .upscale
              .comfyModel,
          legacySeedvr2Model,
        );

        controller.updateComfyUpscaleModule(ComfyUpscaleModule.regular);

        expect(
          firstContainer
              .read(imageWorkflowControllerProvider)
              .upscale
              .comfyModel,
          regularModel,
        );

        await Future<void>.delayed(Duration.zero);
        await Hive.box(StorageKeys.settingsBox).flush();
      } finally {
        firstContainer.dispose();
      }

      final secondContainer = ProviderContainer();
      try {
        final workflow = secondContainer.read(imageWorkflowControllerProvider);

        expect(workflow.upscale.comfyModule, ComfyUpscaleModule.regular);
        expect(workflow.upscale.comfyModel, regularModel);
        expect(workflow.upscale.comfyRegularModel, regularModel);
        expect(workflow.upscale.comfySeedvr2NativeModel, nativeSeedvr2Model);
        expect(workflow.upscale.comfySeedvr2LegacyModel, legacySeedvr2Model);
        expect(workflow.upscale.seedvr2Engine, ComfySeedvr2Engine.legacy);

        secondContainer
            .read(imageWorkflowControllerProvider.notifier)
            .updateComfyUpscaleModule(ComfyUpscaleModule.seedvr2);

        expect(
          secondContainer
              .read(imageWorkflowControllerProvider)
              .upscale
              .comfyModel,
          legacySeedvr2Model,
        );

        secondContainer
            .read(imageWorkflowControllerProvider.notifier)
            .updateSeedvr2Engine(ComfySeedvr2Engine.native);

        expect(
          secondContainer
              .read(imageWorkflowControllerProvider)
              .upscale
              .comfyModel,
          nativeSeedvr2Model,
        );
      } finally {
        secondContainer.dispose();
      }
    });

    test('migrates the previous custom-node SeedVR2 model selection', () async {
      const legacyModel = 'seedvr2_ema_7b_fp16.safetensors';
      await Hive.box(
        StorageKeys.settingsBox,
      ).put(StorageKeys.comfyuiUpscaleSeedvr2Model, legacyModel);

      final container = ProviderContainer();
      try {
        final upscale = container.read(imageWorkflowControllerProvider).upscale;

        expect(upscale.seedvr2Engine, ComfySeedvr2Engine.automatic);
        expect(upscale.comfySeedvr2LegacyModel, legacyModel);
        expect(
          upscale.comfySeedvr2NativeModel,
          UpscaleWorkflowSettings.defaultComfyModel,
        );
      } finally {
        container.dispose();
      }
    });

    test('migrates a previous native-style SeedVR2 model selection', () async {
      const nativeModel = 'seedvr2_7b_fp8_e4m3fn.safetensors';
      await Hive.box(
        StorageKeys.settingsBox,
      ).put(StorageKeys.comfyuiUpscaleSeedvr2Model, nativeModel);

      final container = ProviderContainer();
      try {
        final upscale = container.read(imageWorkflowControllerProvider).upscale;

        expect(upscale.comfySeedvr2NativeModel, nativeModel);
        expect(
          upscale.comfySeedvr2LegacyModel,
          UpscaleWorkflowSettings.defaultLegacyComfyModel,
        );
      } finally {
        container.dispose();
      }
    });
  });

  group('Statistics dashboard', () {
    test('ignores non-positive image dimensions in resolution statistics', () {
      final service = StatisticsService();
      final modifiedAt = DateTime(2026);

      final stats = service.calculateStatistics([
        LocalImageRecord(
          path: 'zero.png',
          size: 1024,
          modifiedAt: modifiedAt,
          metadata: const NaiImageMetadata(width: 0, height: 0),
        ),
        LocalImageRecord(
          path: 'valid.png',
          size: 1024,
          modifiedAt: modifiedAt,
          metadata: const NaiImageMetadata(width: 1024, height: 1024),
        ),
      ]);

      expect(stats.resolutionDistribution.map((r) => r.label), ['1024x1024']);
    });

    testWidgets('aspect ratio card skips invalid cached resolutions', (
      tester,
    ) async {
      final stats = GalleryStatistics(
        totalImages: 2,
        totalSizeBytes: 2048,
        averageFileSizeBytes: 1024,
        resolutionDistribution: const [
          ResolutionStatistics(label: '0x0', count: 1),
          ResolutionStatistics(label: '1024x1024', count: 1),
        ],
        calculatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AspectRatioCard(stats: stats)),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('宽高比分布'), findsOneWidget);
      expect(find.text('1:1'), findsOneWidget);
    });
  });

  group('Dropped file reader URL helpers', () {
    test('extracts Discord CDN image URLs from HTML payloads', () {
      final uri = DroppedFileReader.extractImageUriFromText(
        '<img src="https://media.discordapp.net/attachments/1/2/image.png?ex=abc&amp;is=def">',
      );

      expect(uri, isNotNull);
      expect(uri!.host, 'media.discordapp.net');
      expect(uri.path, '/attachments/1/2/image.png');
      expect(uri.queryParameters['ex'], 'abc');
      expect(uri.queryParameters['is'], 'def');
    });

    test('infers image file names from URL and response headers', () {
      expect(
        DroppedFileReader.inferFileNameFromUri(
          Uri.parse(
            'https://cdn.discordapp.com/attachments/a/b/sample.webp?ex=1',
          ),
        ),
        'sample.webp',
      );
      expect(
        DroppedFileReader.inferFileNameFromUri(
          Uri.parse('https://media.discordapp.net/attachments/a/b/image'),
          contentType: 'image/jpeg',
        ),
        'image.jpg',
      );
      expect(
        DroppedFileReader.inferFileNameFromUri(
          Uri.parse('https://example.test/download'),
          contentDisposition: 'attachment; filename="discord drop.png"',
          contentType: 'image/png',
        ),
        'discord drop.png',
      );
    });
  });

  group('Protection mode settings', () {
    test('gates individual protection features behind the master switch', () {
      const disabled = ShareImageSettings(
        protectionMode: false,
        stripMetadataForCopyAndDrag: true,
        confirmDangerousActions: true,
        warnExternalImageSend: true,
        preventOverwrite: true,
        warnHighAnlasCost: true,
        highAnlasCostThreshold: 50,
        limitGenerationInterval: true,
        generationIntervalSeconds: 15,
      );

      expect(disabled.effectiveStripMetadataForCopyAndDrag, isFalse);
      expect(disabled.effectiveConfirmDangerousActions, isFalse);
      expect(disabled.effectiveWarnExternalImageSend, isFalse);
      expect(disabled.effectivePreventOverwrite, isFalse);
      expect(disabled.effectiveWarnHighAnlasCost, isFalse);
      expect(disabled.effectiveGenerationIntervalSeconds, 0);

      final enabled = disabled.copyWith(protectionMode: true);
      expect(enabled.effectiveStripMetadataForCopyAndDrag, isTrue);
      expect(enabled.effectiveConfirmDangerousActions, isTrue);
      expect(enabled.effectiveWarnExternalImageSend, isTrue);
      expect(enabled.effectivePreventOverwrite, isTrue);
      expect(enabled.effectiveWarnHighAnlasCost, isTrue);
      expect(enabled.effectiveGenerationIntervalSeconds, 15);
    });

    test('allows each protection feature to be disabled independently', () {
      const settings = ShareImageSettings(
        protectionMode: true,
        stripMetadataForCopyAndDrag: false,
        confirmDangerousActions: false,
        warnExternalImageSend: false,
        preventOverwrite: false,
        warnHighAnlasCost: false,
        highAnlasCostThreshold: 50,
        limitGenerationInterval: false,
        generationIntervalSeconds: 15,
      );

      expect(settings.effectiveStripMetadataForCopyAndDrag, isFalse);
      expect(settings.effectiveConfirmDangerousActions, isFalse);
      expect(settings.effectiveWarnExternalImageSend, isFalse);
      expect(settings.effectivePreventOverwrite, isFalse);
      expect(settings.effectiveWarnHighAnlasCost, isFalse);
      expect(settings.effectiveGenerationIntervalSeconds, 0);
    });
  });

  group('Prompt assistant defaults', () {
    test('contains immutable defaults for all assistant task types', () {
      final defaults = PromptAssistantConfigState.defaults();
      expect(defaults.streamOutput, isFalse);
      expect(defaults.providers, isEmpty);
      expect(defaults.models, isEmpty);

      for (final taskType in AssistantTaskType.values) {
        if (taskType == AssistantTaskType.chat) {
          continue;
        }
        expect(
          defaults.rules.any(
            (rule) => rule.taskType == taskType && rule.isDefault,
          ),
          isTrue,
        );
        expect(defaults.routing.providerIdFor(taskType), isEmpty);
        expect(defaults.routing.modelFor(taskType), isEmpty);
      }
    });

    test('pollinations is available as a normal provider preset', () {
      const preset = ProviderPreset.pollinations;

      expect(preset.defaultName, 'pollinations.ai');
      expect(preset.defaultProtocol, ProviderProtocol.openaiChatCompletions);
      expect(preset.defaultBaseUrl, 'https://gen.pollinations.ai');
    });

    test('migrates old untouched pollinations defaults out of providers', () {
      final oldJson = <String, dynamic>{
        'enabled': true,
        'desktopOverlayEnabled': true,
        'streamOutput': false,
        'providers': [
          {
            'id': 'pollinations',
            'name': 'pollinations.ai',
            'type': 'pollinations',
            'baseUrl': 'https://gen.pollinations.ai',
            'enabled': true,
          },
          {
            'id': 'openai_custom',
            'name': 'OpenAI Compatible',
            'type': 'openaiCompatible',
            'baseUrl': 'https://api.openai.com/v1',
            'enabled': false,
          },
          {
            'id': 'ollama',
            'name': 'Ollama',
            'type': 'ollama',
            'baseUrl': 'http://127.0.0.1:11434/v1',
            'enabled': false,
          },
        ],
        'models': [
          for (final taskType in [
            AssistantTaskType.llm,
            AssistantTaskType.translate,
            AssistantTaskType.reverse,
            AssistantTaskType.characterReplace,
          ])
            {
              'providerId': 'pollinations',
              'name': 'openai-large',
              'displayName': 'openai-large',
              'forTask': taskType.name,
              'isDefault': true,
            },
        ],
        'routing': const TaskRoutingConfig(
          llmProviderId: 'pollinations',
          llmModel: 'openai-large',
          translateProviderId: 'pollinations',
          translateModel: 'openai-large',
          reverseProviderId: 'pollinations',
          reverseModel: 'openai-large',
          characterReplaceProviderId: 'pollinations',
          characterReplaceModel: 'openai-large',
        ).toJson(),
        'rules': PromptAssistantConfigState.defaults().rules
            .map((rule) => rule.toJson())
            .toList(),
      };

      final decoded = PromptAssistantConfigState.decode(jsonEncode(oldJson));

      expect(
        decoded.providers.any((provider) => provider.id == 'pollinations'),
        isFalse,
      );
      for (final taskType in AssistantTaskType.values) {
        expect(decoded.routing.providerIdFor(taskType), isEmpty);
        expect(decoded.routing.modelFor(taskType), isEmpty);
      }
    });

    test(
      'hydrates reverse and character replacement routing from old config',
      () {
        final oldConfig =
            PromptAssistantConfigState.defaults()
                .copyWith(
                  providers: const [
                    ProviderConfig(
                      id: 'openai_custom',
                      name: 'OpenAI Compatible',
                      type: ProviderType.openaiCompatible,
                      baseUrl: 'https://example.invalid/v1',
                      enabled: true,
                    ),
                  ],
                  models: const [
                    ModelConfig(
                      providerId: 'openai_custom',
                      name: 'model-a',
                      displayName: 'model-a',
                      forTask: AssistantTaskType.llm,
                    ),
                    ModelConfig(
                      providerId: 'openai_custom',
                      name: 'model-a',
                      displayName: 'model-a',
                      forTask: AssistantTaskType.translate,
                    ),
                  ],
                  rules: PromptAssistantConfigState.defaults().rules
                      .where(
                        (rule) =>
                            rule.taskType == AssistantTaskType.llm ||
                            rule.taskType == AssistantTaskType.translate,
                      )
                      .toList(),
                )
                .toJson()
              ..['routing'] = const TaskRoutingConfig(
                llmProviderId: 'openai_custom',
                llmModel: 'model-a',
                translateProviderId: 'openai_custom',
                translateModel: 'model-a',
                reverseProviderId: '',
                reverseModel: '',
                characterReplaceProviderId: '',
                characterReplaceModel: '',
              ).toJson();

        final decoded = PromptAssistantConfigState.decode(
          PromptAssistantConfigState(
            enabled: oldConfig['enabled'] as bool,
            desktopOverlayEnabled: oldConfig['desktopOverlayEnabled'] as bool,
            streamOutput: oldConfig['streamOutput'] as bool,
            providers: (oldConfig['providers'] as List)
                .cast<Map<String, dynamic>>()
                .map(ProviderConfig.fromJson)
                .toList(),
            models: (oldConfig['models'] as List)
                .cast<Map<String, dynamic>>()
                .map(ModelConfig.fromJson)
                .toList(),
            routing: TaskRoutingConfig.fromJson(
              (oldConfig['routing'] as Map).cast<String, dynamic>(),
            ),
            rules: (oldConfig['rules'] as List)
                .cast<Map<String, dynamic>>()
                .map(PromptRuleTemplate.fromJson)
                .toList(),
            providerHasApiKey: const {},
          ).encode(),
        );

        expect(decoded.streamOutput, isFalse);
        expect(
          decoded.models.any(
            (model) => model.forTask == AssistantTaskType.reverse,
          ),
          isTrue,
        );
        expect(
          decoded.models.any(
            (model) => model.forTask == AssistantTaskType.characterReplace,
          ),
          isTrue,
        );
        expect(
          decoded.rules.any(
            (rule) => rule.taskType == AssistantTaskType.reverse,
          ),
          isTrue,
        );
        expect(
          decoded.rules.any(
            (rule) => rule.taskType == AssistantTaskType.characterReplace,
          ),
          isTrue,
        );
        expect(
          decoded.routing.providerIdFor(AssistantTaskType.reverse),
          'openai_custom',
        );
        expect(
          decoded.routing.providerIdFor(AssistantTaskType.characterReplace),
          'openai_custom',
        );
      },
    );

    test('reuses pulled provider models for reverse and character tasks', () {
      const providerId = 'openai_custom';
      const modelName = '[PAY]gemini-3.1-pro-preview';
      final defaults = PromptAssistantConfigState.defaults();

      final decoded = PromptAssistantConfigState.decode(
        defaults
            .copyWith(
              providers: const [
                ProviderConfig(
                  id: providerId,
                  name: 'OpenAI Compatible',
                  type: ProviderType.openaiCompatible,
                  baseUrl: 'https://example.invalid/v1',
                  enabled: true,
                ),
              ],
              models: const [
                ModelConfig(
                  providerId: providerId,
                  name: modelName,
                  displayName: modelName,
                  forTask: AssistantTaskType.llm,
                ),
                ModelConfig(
                  providerId: providerId,
                  name: modelName,
                  displayName: modelName,
                  forTask: AssistantTaskType.translate,
                ),
                ModelConfig(
                  providerId: providerId,
                  name: 'default-model',
                  displayName: 'default-model',
                  forTask: AssistantTaskType.reverse,
                  isDefault: true,
                ),
                ModelConfig(
                  providerId: providerId,
                  name: 'default-model',
                  displayName: 'default-model',
                  forTask: AssistantTaskType.characterReplace,
                  isDefault: true,
                ),
              ],
              routing: const TaskRoutingConfig(
                llmProviderId: providerId,
                llmModel: modelName,
                translateProviderId: providerId,
                translateModel: modelName,
                reverseProviderId: providerId,
                reverseModel: 'default-model',
                characterReplaceProviderId: providerId,
                characterReplaceModel: 'default-model',
              ),
            )
            .encode(),
      );

      for (final taskType in [
        AssistantTaskType.reverse,
        AssistantTaskType.characterReplace,
      ]) {
        final models = decoded.modelsForProviderTask(
          providerId: providerId,
          taskType: taskType,
        );
        expect(models.map((model) => model.name), contains(modelName));
        expect(models.first.name, modelName);
        expect(decoded.routing.modelFor(taskType), modelName);
      }
    });

    test('migrates legacy model sources without deleting default models', () {
      final pulledModel = ModelConfig.fromJson({
        'providerId': 'openai_custom',
        'name': 'old-api-model',
        'displayName': 'old-api-model',
        'forTask': AssistantTaskType.llm.name,
        'isDefault': false,
      });
      final defaultModel = ModelConfig.fromJson({
        'providerId': 'openai_custom',
        'name': 'default-model',
        'displayName': 'default-model',
        'forTask': AssistantTaskType.llm.name,
        'isDefault': true,
      });

      expect(pulledModel.source, ModelSource.api);
      expect(defaultModel.source, ModelSource.manual);
    });

    test('refresh replaces stale API models and keeps manual models', () async {
      final localStorage = _MockLocalStorageService();
      when(
        () => localStorage.getSetting<String>(
          StorageKeys.promptAssistantConfigJson,
        ),
      ).thenReturn(null);
      when(
        () => localStorage.setSetting<String>(
          StorageKeys.promptAssistantConfigJson,
          any(),
        ),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(promptAssistantConfigProvider.notifier);
      const providerId = 'openai_custom';
      await notifier.upsertProvider(
        const ProviderConfig(
          id: providerId,
          name: 'OpenAI Compatible',
          type: ProviderType.openaiCompatible,
          baseUrl: 'https://example.invalid/v1',
          enabled: true,
        ),
      );
      await notifier.upsertModel(
        const ModelConfig(
          providerId: providerId,
          name: 'old-api-model',
          displayName: 'old-api-model',
          forTask: AssistantTaskType.llm,
          source: ModelSource.api,
        ),
      );
      await notifier.upsertModel(
        const ModelConfig(
          providerId: providerId,
          name: 'manual-model',
          displayName: 'manual-model',
          forTask: AssistantTaskType.llm,
        ),
      );
      await notifier.setRouting(
        container
            .read(promptAssistantConfigProvider)
            .routing
            .copyWithTask(
              taskType: AssistantTaskType.llm,
              providerId: providerId,
              model: 'old-api-model',
            ),
      );

      final removed = await notifier.syncProviderModels(providerId, const [
        'new-api-model',
      ]);
      final state = container.read(promptAssistantConfigProvider);

      expect(removed, ['old-api-model']);
      expect(
        state.models.any((model) => model.name == 'old-api-model'),
        isFalse,
      );
      expect(state.models.any((model) => model.name == 'manual-model'), isTrue);
      for (final taskType in AssistantTaskType.values) {
        expect(
          state.models.any(
            (model) =>
                model.providerId == providerId &&
                model.forTask == taskType &&
                model.name == 'new-api-model' &&
                model.source == ModelSource.api,
          ),
          isTrue,
        );
      }
      expect(state.routing.modelFor(AssistantTaskType.llm), 'new-api-model');
    });
  });

  group('Prompt assistant API client', () {
    test(
      'character replacement payload keeps source prompt as primary input',
      () {
        final payload =
            PromptAssistantService.buildCharacterReplacementUserContent(
              sourcePrompt: '1girl, sitting, classroom, looking at viewer',
              characterName: 'target',
              characterPrompt: 'target girl, silver hair, blue dress',
            );

        expect(payload, contains('Source prompt to replace'));
        expect(
          payload,
          contains('1girl, sitting, classroom, looking at viewer'),
        );
        expect(payload, isNot(contains('源语境标签')));
        expect(payload, contains('Target character prompt'));
        expect(payload, contains('target girl, silver hair, blue dress'));
        expect(
          payload.indexOf('1girl, sitting, classroom'),
          lessThan(payload.indexOf('target girl, silver hair')),
        );
        expect(
          PromptAssistantService.characterReplacementInstruction,
          contains('Do not output analysis'),
        );
      },
    );

    test('sends chat requests as non-streaming JSON', () async {
      final dio = _MockDio();
      final client = PromptAssistantApiClient(dio: dio);

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final payload = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        final options = invocation.namedArguments[#options] as Options;
        expect(payload['stream'], isFalse);
        expect(payload.containsKey('temperature'), isFalse);
        expect(payload.containsKey('top_p'), isFalse);
        expect(payload.containsKey('max_tokens'), isFalse);
        expect(options.responseType, isNot(ResponseType.stream));
        return Response<dynamic>(
          data: const {
            'choices': [
              {
                'message': {'content': 'hello'},
              },
            ],
          },
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          statusCode: 200,
        );
      });

      final chunks = await client
          .complete(
            request: const PromptAssistantRequest(
              sessionId: 'test',
              provider: ProviderConfig(
                id: 'openai_custom',
                name: 'OpenAI Compatible',
                type: ProviderType.openaiCompatible,
                baseUrl: 'https://example.invalid/v1',
              ),
              model: 'model-a',
              systemPrompt: '',
              userParts: [PromptAssistantTextPart('test')],
              apiKey: 'key',
            ),
          )
          .toList();

      expect(
        chunks.where((chunk) => !chunk.done).map((chunk) => chunk.delta).join(),
        'hello',
      );
      expect(chunks.last.done, isTrue);
    });

    test('supports bounded non-thinking JSON requests for DeepSeek', () async {
      final dio = _MockDio();
      final client = PromptAssistantApiClient(dio: dio);

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final payload = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        expect(payload['response_format'], {'type': 'json_object'});
        expect(payload['max_tokens'], 512);
        expect(payload['thinking'], {'type': 'disabled'});
        return Response<dynamic>(
          data: const {
            'choices': [
              {
                'message': {'content': '{"blue_eyes":"蓝眼睛"}'},
              },
            ],
          },
          requestOptions: RequestOptions(path: '/chat/completions'),
          statusCode: 200,
        );
      });

      final chunks = await client
          .complete(
            request: PromptAssistantRequest(
              sessionId: 'tag-translation',
              provider: ProviderPreset.deepseek.createConfig(),
              model: 'deepseek-chat',
              systemPrompt: 'Return one JSON object.',
              userParts: const [PromptAssistantTextPart('["blue_eyes"]')],
              apiKey: 'key',
              responseFormat: PromptAssistantResponseFormat.jsonObject,
              maxOutputTokens: 512,
              reasoningMode: PromptAssistantReasoningMode.disabled,
            ),
          )
          .toList();

      expect(chunks.first.delta, '{"blue_eyes":"蓝眼睛"}');
      expect(chunks.last.done, isTrue);
    });

    test(
      'throws a visible error when the non-stream response has no content',
      () async {
        final dio = _MockDio();
        final client = PromptAssistantApiClient(dio: dio);

        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            data: const {'choices': <Object>[]},
            requestOptions: RequestOptions(path: '/v1/chat/completions'),
            statusCode: 200,
          ),
        );

        expect(
          () => client
              .complete(
                request: const PromptAssistantRequest(
                  sessionId: 'test',
                  provider: ProviderConfig(
                    id: 'openai_custom',
                    name: 'OpenAI Compatible',
                    type: ProviderType.openaiCompatible,
                    baseUrl: 'https://example.invalid/v1',
                  ),
                  model: 'model-a',
                  systemPrompt: '',
                  userParts: [PromptAssistantTextPart('test')],
                  apiKey: 'key',
                ),
              )
              .drain<void>(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('retries non-streaming on 400 without sampling params', () async {
      final dio = _MockDio();
      final client = PromptAssistantApiClient(dio: dio);
      var callCount = 0;

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        callCount++;
        final payload = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        expect(payload['stream'], isFalse);
        if (callCount == 1) {
          expect(payload.containsKey('temperature'), isFalse);
          expect(payload.containsKey('top_p'), isFalse);
          expect(payload.containsKey('max_tokens'), isFalse);
          throw DioException(
            requestOptions: RequestOptions(path: '/v1/chat/completions'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/v1/chat/completions'),
              statusCode: 400,
            ),
          );
        }
        expect(payload.containsKey('temperature'), isFalse);
        expect(payload.containsKey('top_p'), isFalse);
        expect(payload.containsKey('max_tokens'), isFalse);
        return Response<dynamic>(
          data: const {
            'choices': [
              {
                'message': {'content': 'fallback result'},
              },
            ],
          },
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          statusCode: 200,
        );
      });

      final chunks = await client
          .complete(
            request: const PromptAssistantRequest(
              sessionId: 'test',
              provider: ProviderConfig(
                id: 'openai_custom',
                name: 'OpenAI Compatible',
                type: ProviderType.openaiCompatible,
                baseUrl: 'https://example.invalid/v1',
              ),
              model: 'model-a',
              systemPrompt: '',
              userParts: [PromptAssistantTextPart('test')],
              apiKey: 'key',
            ),
          )
          .toList();

      expect(
        chunks.where((chunk) => !chunk.done).map((chunk) => chunk.delta).join(),
        'fallback result',
      );
      expect(chunks.last.done, isTrue);
      expect(callCount, 2);
    });

    test('sends OpenAI Responses payload to responses endpoint', () async {
      final dio = _MockDio();
      final client = PromptAssistantApiClient(dio: dio);

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final endpoint = invocation.positionalArguments.first as String;
        final payload = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        expect(endpoint, 'https://api.openai.com/v1/responses');
        expect(payload['instructions'], isEmpty);
        expect(payload['input'], isA<List>());
        final input = (payload['input'] as List).first as Map;
        final content = input['content'] as List;
        expect((content.first as Map)['type'], 'input_text');
        return Response<dynamic>(
          data: const {'output_text': 'response result'},
          requestOptions: RequestOptions(path: '/v1/responses'),
          statusCode: 200,
        );
      });

      final chunks = await client
          .complete(
            request: const PromptAssistantRequest(
              sessionId: 'test',
              provider: ProviderConfig(
                id: 'openai_responses',
                name: 'OpenAI Responses',
                protocol: ProviderProtocol.openaiResponses,
                preset: ProviderPreset.openaiResponses,
                baseUrl: 'https://api.openai.com/v1',
              ),
              model: 'gpt-4.1-mini',
              systemPrompt: '',
              userParts: [PromptAssistantTextPart('test')],
              apiKey: 'key',
            ),
          )
          .toList();

      expect(
        chunks.where((chunk) => !chunk.done).map((chunk) => chunk.delta).join(),
        'response result',
      );
    });

    test('sends LM Studio Responses to local responses endpoint', () async {
      final dio = _MockDio();
      final client = PromptAssistantApiClient(dio: dio);

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final endpoint = invocation.positionalArguments.first as String;
        expect(endpoint, 'http://localhost:1234/v1/responses');
        return Response<dynamic>(
          data: const {'output_text': 'local result'},
          requestOptions: RequestOptions(path: '/v1/responses'),
          statusCode: 200,
        );
      });

      final chunks = await client
          .complete(
            request: const PromptAssistantRequest(
              sessionId: 'test',
              provider: ProviderConfig(
                id: 'lmstudio_responses',
                name: 'LM Studio Responses',
                protocol: ProviderProtocol.openaiResponses,
                preset: ProviderPreset.lmStudioResponses,
                baseUrl: 'http://localhost:1234/v1',
              ),
              model: 'local-model',
              systemPrompt: '',
              userParts: [PromptAssistantTextPart('test')],
              apiKey: null,
            ),
          )
          .toList();

      expect(
        chunks.where((chunk) => !chunk.done).map((chunk) => chunk.delta).join(),
        'local result',
      );
    });

    test(
      'sends Anthropic messages with system and x-api-key headers',
      () async {
        final dio = _MockDio();
        final client = PromptAssistantApiClient(dio: dio);

        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) async {
          final endpoint = invocation.positionalArguments.first as String;
          final payload = Map<String, dynamic>.from(
            invocation.namedArguments[#data] as Map,
          );
          final options = invocation.namedArguments[#options] as Options;
          expect(endpoint, 'https://api.anthropic.com/v1/messages');
          expect(payload['system'], 'system prompt');
          expect(options.headers?['x-api-key'], 'key');
          expect(options.headers?['anthropic-version'], '2023-06-01');
          return Response<dynamic>(
            data: const {
              'content': [
                {'type': 'text', 'text': 'anthropic result'},
              ],
            },
            requestOptions: RequestOptions(path: '/v1/messages'),
            statusCode: 200,
          );
        });

        final chunks = await client
            .complete(
              request: const PromptAssistantRequest(
                sessionId: 'test',
                provider: ProviderConfig(
                  id: 'anthropic',
                  name: 'Anthropic',
                  protocol: ProviderProtocol.anthropicMessages,
                  preset: ProviderPreset.anthropic,
                  baseUrl: 'https://api.anthropic.com',
                ),
                model: 'claude-sonnet-4-20250514',
                systemPrompt: 'system prompt',
                userParts: [PromptAssistantTextPart('test')],
                apiKey: 'key',
              ),
            )
            .toList();

        expect(
          chunks
              .where((chunk) => !chunk.done)
              .map((chunk) => chunk.delta)
              .join(),
          'anthropic result',
        );
      },
    );

    test('sends Gemini generateContent payload', () async {
      final dio = _MockDio();
      final client = PromptAssistantApiClient(dio: dio);

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final endpoint = invocation.positionalArguments.first as String;
        final payload = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        final options = invocation.namedArguments[#options] as Options;
        expect(
          endpoint,
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
        );
        expect(options.headers?['x-goog-api-key'], 'key');
        expect(options.receiveTimeout, Duration.zero);
        expect(payload['systemInstruction'], isA<Map>());
        return Response<dynamic>(
          data: const {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'gemini result'},
                  ],
                },
              },
            ],
          },
          requestOptions: RequestOptions(path: '/generateContent'),
          statusCode: 200,
        );
      });

      final chunks = await client
          .complete(
            request: const PromptAssistantRequest(
              sessionId: 'test',
              provider: ProviderConfig(
                id: 'gemini',
                name: 'Gemini',
                protocol: ProviderProtocol.geminiGenerateContent,
                preset: ProviderPreset.gemini,
                baseUrl: 'https://generativelanguage.googleapis.com',
              ),
              model: 'gemini-2.5-flash',
              systemPrompt: 'system prompt',
              userParts: [PromptAssistantTextPart('test')],
              apiKey: 'key',
            ),
          )
          .toList();

      expect(
        chunks.where((chunk) => !chunk.done).map((chunk) => chunk.delta).join(),
        'gemini result',
      );
    });

    test('compresses oversized image parts before LLM upload', () async {
      const maxBytes = 20 * 1024;
      final originalBytes = _buildNoisyPngBytes(width: 512, height: 384);
      final originalImage = img.decodeImage(originalBytes)!;

      expect(originalBytes.length, greaterThan(maxBytes));

      final optimized = await optimizePromptAssistantImagePartForUpload(
        PromptAssistantImagePart(bytes: originalBytes, mimeType: 'image/png'),
        maxBytes: maxBytes,
      );
      final optimizedImage = img.decodeImage(optimized.bytes)!;

      expect(optimized.bytes.length, lessThanOrEqualTo(maxBytes));
      expect(optimized.mimeType, 'image/jpeg');
      expect(optimizedImage.width, lessThan(originalImage.width));
      expect(optimizedImage.height, lessThan(originalImage.height));
      expect(
        optimizedImage.width / optimizedImage.height,
        closeTo(originalImage.width / originalImage.height, 0.02),
      );
    });

    test('compresses typed image payload before posting', () async {
      const maxBytes = 20 * 1024;
      final dio = _MockDio();
      final client = PromptAssistantApiClient(
        dio: dio,
        imageUploadMaxBytes: maxBytes,
      );
      final originalBytes = _buildNoisyPngBytes(width: 512, height: 384);

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final payload = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        final messages = payload['messages'] as List;
        final userMessage = messages.last as Map;
        final content = userMessage['content'] as List;
        final imagePart = content.last as Map;
        final imageUrl = imagePart['image_url'] as Map;
        final parsed = parseDataUriImage(imageUrl['url'] as String)!;

        expect(parsed.bytes.length, lessThanOrEqualTo(maxBytes));
        expect(parsed.mimeType, 'image/jpeg');

        return Response<dynamic>(
          data: const {
            'choices': [
              {
                'message': {'content': 'compressed'},
              },
            ],
          },
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          statusCode: 200,
        );
      });

      final chunks = await client
          .complete(
            request: PromptAssistantRequest(
              sessionId: 'test',
              provider: const ProviderConfig(
                id: 'openai_custom',
                name: 'OpenAI Compatible',
                type: ProviderType.openaiCompatible,
                baseUrl: 'https://example.invalid/v1',
              ),
              model: 'model-a',
              systemPrompt: '',
              userParts: [
                const PromptAssistantTextPart('describe'),
                PromptAssistantImagePart(
                  bytes: originalBytes,
                  mimeType: 'image/png',
                ),
              ],
              apiKey: 'key',
            ),
          )
          .toList();

      expect(
        chunks.where((chunk) => !chunk.done).map((chunk) => chunk.delta).join(),
        'compressed',
      );
    });

    test(
      'normalizes small PNG image payloads to JPEG before posting',
      () async {
        final dio = _MockDio();
        final client = PromptAssistantApiClient(dio: dio);
        final originalBytes = _buildNoisyPngBytes(width: 32, height: 24);

        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) async {
          final payload = Map<String, dynamic>.from(
            invocation.namedArguments[#data] as Map,
          );
          final messages = payload['messages'] as List;
          final userMessage = messages.last as Map;
          final content = userMessage['content'] as List;
          final imagePart = content.last as Map;
          final imageUrl = imagePart['image_url'] as Map;
          final parsed = parseDataUriImage(imageUrl['url'] as String)!;
          final decoded = img.decodeImage(parsed.bytes)!;

          expect(parsed.mimeType, 'image/jpeg');
          expect(decoded.width, 32);
          expect(decoded.height, 24);

          return Response<dynamic>(
            data: const {
              'choices': [
                {
                  'message': {'content': 'normalized'},
                },
              ],
            },
            requestOptions: RequestOptions(path: '/v1/chat/completions'),
            statusCode: 200,
          );
        });

        final chunks = await client
            .complete(
              request: PromptAssistantRequest(
                sessionId: 'test',
                provider: const ProviderConfig(
                  id: 'openai_custom',
                  name: 'OpenAI Compatible',
                  type: ProviderType.openaiCompatible,
                  baseUrl: 'https://example.invalid/v1',
                ),
                model: 'model-a',
                systemPrompt: '',
                userParts: [
                  const PromptAssistantTextPart('describe'),
                  PromptAssistantImagePart(
                    bytes: originalBytes,
                    mimeType: 'image/png',
                  ),
                ],
                apiKey: 'key',
              ),
            )
            .toList();

        expect(
          chunks
              .where((chunk) => !chunk.done)
              .map((chunk) => chunk.delta)
              .join(),
          'normalized',
        );
      },
    );

    test('surfaces provider HTTP error bodies', () async {
      final dio = _MockDio();
      final client = PromptAssistantApiClient(dio: dio);

      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/chat/completions'),
          response: Response<dynamic>(
            data: const {
              'error': {
                'message': 'upstream internal error',
                'type': 'server_error',
              },
            },
            requestOptions: RequestOptions(
              path: 'https://example.invalid/v1/chat/completions?key=secret',
            ),
            statusCode: 503,
          ),
        ),
      );

      await expectLater(
        client
            .complete(
              request: const PromptAssistantRequest(
                sessionId: 'test',
                provider: ProviderConfig(
                  id: 'openai_custom',
                  name: 'OpenAI Compatible',
                  type: ProviderType.openaiCompatible,
                  baseUrl: 'https://example.invalid/v1',
                ),
                model: 'model-a',
                systemPrompt: '',
                userParts: [PromptAssistantTextPart('test')],
                apiKey: 'key',
              ),
            )
            .drain<void>(),
        throwsA(
          isA<StateError>()
              .having((e) => e.toString(), 'message', contains('HTTP 503'))
              .having(
                (e) => e.toString(),
                'message',
                contains('upstream internal error'),
              )
              .having(
                (e) => e.toString(),
                'message',
                isNot(contains('secret')),
              ),
        ),
      );
    });
  });

  group('Prompt assistant fixed tag scope', () {
    test(
      'strips enabled fixed prefixes and suffixes before assistant tasks',
      () {
        final state = FixedTagsState(
          entries: [
            FixedTagEntry.create(
              name: 'quality',
              content: 'masterpiece, best quality',
              position: FixedTagPosition.prefix,
            ),
            FixedTagEntry.create(
              name: 'suffix',
              content: 'highres',
              position: FixedTagPosition.suffix,
            ),
            FixedTagEntry.create(
              name: 'disabled',
              content: 'keep_me',
              enabled: false,
              position: FixedTagPosition.prefix,
            ),
          ],
        );

        expect(
          state.stripFromPrompt(
            'masterpiece, best quality, 1girl, smile, highres',
          ),
          '1girl, smile',
        );
        expect(state.stripFromPrompt('1girl, smile'), '1girl, smile');
        expect(
          state.stripFromPrompt('keep_me, 1girl, highres'),
          'keep_me, 1girl',
        );
      },
    );
  });

  group('ONNX tagger categories', () {
    test('keeps only general and character label categories by default', () {
      expect(
        const OnnxTaggerLabel(name: '1girl', category: 'General').isGeneral,
        isTrue,
      );
      expect(
        const OnnxTaggerLabel(
          name: 'hakurei_reimu',
          category: 'Character',
        ).isCharacter,
        isTrue,
      );
      expect(
        const OnnxTaggerLabel(name: '1girl', category: '0').isGeneral,
        isTrue,
      );
      expect(
        const OnnxTaggerLabel(name: 'hakurei_reimu', category: '4').isCharacter,
        isTrue,
      );
      expect(
        const OnnxTaggerLabel(name: 'general', category: 'Rating').isRating,
        isTrue,
      );
      expect(
        const OnnxTaggerLabel(
          name: 'artist_name',
          category: 'Artist',
        ).labelCategory,
        OnnxTaggerLabelCategory.other,
      );
    });
  });

  group('Prompt injected history', () {
    test('supports external undo and redo for injected prompts', () {
      final history = PromptAssistantHistoryNotifier();
      history.recordExternalChange(
        PromptHistorySessionIds.generationPrompt,
        before: 'old prompt',
        after: 'reverse prompt',
      );

      expect(
        history.undoExternal(
          PromptHistorySessionIds.generationPrompt,
          'reverse prompt',
        ),
        'old prompt',
      );
      expect(
        history.redoExternal(
          PromptHistorySessionIds.generationPrompt,
          'old prompt',
        ),
        'reverse prompt',
      );
      expect(
        history.undoExternal(
          PromptHistorySessionIds.generationPrompt,
          'manual edit after injection',
        ),
        isNull,
      );
    });
  });
}

Future<void> _pumpOnlineGalleryScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onlineGalleryNotifierProvider.overrideWith(
          _FakeOnlineGalleryNotifier.new,
        ),
        danbooruSuggestionNotifierProvider.overrideWith(
          _FakeDanbooruSuggestionNotifier.new,
        ),
        autocompleteLocalSourcesProvider.overrideWithValue(const [
          _FakeCompletionSource(),
        ]),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnlineGalleryScreen(),
      ),
    ),
  );
}

class _FakeCompletionSource implements CompletionSource {
  const _FakeCompletionSource();

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    final canonicalTag = switch (query.token) {
      'rai' => 'raiden_shogun',
      'lo' => 'long_hair',
      _ => query.token,
    };
    if (canonicalTag.isEmpty) return const [];
    return [
      CompletionCandidate(
        canonicalTag: canonicalTag,
        category: canonicalTag == 'raiden_shogun'
            ? TagCategory.character
            : TagCategory.general,
        postCount: 1000,
        matchKind: CompletionMatchKind.englishPrefix,
        sources: const {CompletionSourceKind.base},
      ),
    ];
  }
}

class _FakeOnlineGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() => const OnlineGalleryState();

  @override
  Future<void> loadPosts({bool refresh = false}) async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
  }

  @override
  Future<void> setFuzzySearchEnabled(bool enabled) async {
    state = state.copyWith(fuzzySearchEnabled: enabled);
  }

  @override
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    state = state.copyWith(
      dateRangeStart: start,
      dateRangeEnd: end,
      clearDateRange: start == null && end == null,
    );
  }
}

class _FakeDanbooruSuggestionNotifier extends DanbooruSuggestionNotifier {
  @override
  TagSuggestionState build() => const TagSuggestionState();

  @override
  void search(String query, {bool immediate = false}) {
    final suggestion = switch (query) {
      'foot_focus' => const TagSuggestion(tag: 'foot_focus'),
      'lo' => const TagSuggestion(tag: 'long_hair'),
      _ => null,
    };
    if (suggestion == null) return;

    state = TagSuggestionState(suggestions: [suggestion], currentQuery: query);
  }

  @override
  void clear() {
    state = const TagSuggestionState();
  }
}

class _FakeLocalGalleryNotifier extends LocalGalleryNotifier {
  @override
  LocalGalleryState build() =>
      const LocalGalleryState(isInitialized: true, totalPages: 1);

  @override
  Future<void> setSearchQuery(String query) async {}

  @override
  Future<void> clearAllFilters() async {}
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _FakeTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() =>
      const TagLibraryPageState(searchQuery: 'rabbit');
}

VibeLibraryEntry _buildVibeEntry({
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
    createdAt: DateTime(2026, 5, 2),
  );
}

Uint8List _buildNoisyPngBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 37 + y * 17) & 0xff,
        (x * 13 + y * 47) & 0xff,
        (x * 53 + y * 29) & 0xff,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
