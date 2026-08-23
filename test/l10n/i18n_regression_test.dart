import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/comfyui/comfyui.dart';
import 'package:nai_launcher/data/services/vibe_bulk_operation_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/bulk_operation_provider.dart';
import 'package:nai_launcher/presentation/providers/category_operation_error.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/utils/vibe_bulk_operation_l10n.dart';

void main() {
  group('ARB parity', () {
    late Map<String, dynamic> english;

    setUpAll(() {
      english = _readArb('lib/l10n/app_en.arb');
    });

    for (final locale in const ['en', 'ja', 'zh', 'zh_Hant']) {
      test('$locale does not contain duplicate top-level keys', () {
        final keys = _topLevelKeys('lib/l10n/app_$locale.arb');
        final counts = <String, int>{};
        for (final key in keys) {
          counts.update(key, (count) => count + 1, ifAbsent: () => 1);
        }
        final duplicates = counts.entries
            .where((entry) => entry.value > 1)
            .map((entry) => entry.key)
            .toSet();

        expect(duplicates, isEmpty);
      });
    }

    for (final locale in const ['ja', 'zh', 'zh_Hant']) {
      test('$locale matches the template keys and metadata', () {
        final localized = _readArb('lib/l10n/app_$locale.arb');

        expect(_messageKeys(localized), _messageKeys(english));
        expect(_metadataKeys(localized), _metadataKeys(english));

        for (final key in _messageKeys(english)) {
          expect(
            _placeholders(localized[key] as String),
            _placeholders(english[key] as String),
            reason: 'Placeholder mismatch for $key in $locale',
          );
        }
      });
    }

    test('template does not contain unreferenced message keys', () {
      final references = _productionLocalizationReferences();
      final unused = _messageKeys(english).difference(references).toList()
        ..sort();

      expect(
        unused,
        isEmpty,
        reason: 'Remove ARB messages with no production reference: $unused',
      );
    });
  });

  group('localized provider errors', () {
    final localizations = <String, AppLocalizations>{
      'en': lookupAppLocalizations(const Locale('en')),
      'ja': lookupAppLocalizations(const Locale('ja')),
      'zh': lookupAppLocalizations(const Locale('zh')),
      'zh_Hant': lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
    };

    test('ComfyUI errors are localized at the UI boundary', () {
      const state = ComfyUITaskState(
        status: ComfyUITaskStatus.failed,
        errorCode: ComfyUITaskErrorCode.workflowNotFound,
        errorDetails: 'upscale',
      );

      expect(
        state.localizedError(localizations['en']!),
        'Workflow not found: upscale',
      );
      expect(
        state.localizedError(localizations['ja']!),
        'ワークフローが見つかりません: upscale',
      );
      expect(state.localizedError(localizations['zh']!), '未找到工作流：upscale');
    });

    test('ComfyUI generic failures and timeouts do not expose fallbacks', () {
      const genericFailure = ComfyUITaskState(
        status: ComfyUITaskStatus.failed,
        errorCode: ComfyUITaskErrorCode.executionFailed,
      );
      const timeout = ComfyUITaskState(
        status: ComfyUITaskStatus.failed,
        errorCode: ComfyUITaskErrorCode.timeout,
      );

      expect(
        genericFailure.localizedError(localizations['en']!),
        'ComfyUI execution failed',
      );
      expect(
        genericFailure.localizedError(localizations['ja']!),
        'ComfyUI の実行に失敗しました',
      );
      expect(
        genericFailure.localizedError(localizations['zh']!),
        'ComfyUI 执行失败',
      );
      expect(
        timeout.localizedError(localizations['en']!),
        'The ComfyUI task timed out after 10 minutes',
      );
      expect(
        timeout.localizedError(localizations['ja']!),
        'ComfyUI タスクが 10 分でタイムアウトしました',
      );
      expect(
        timeout.localizedError(localizations['zh']!),
        'ComfyUI 任务已在 10 分钟后超时',
      );
    });

    test('gallery errors retain details in every locale', () {
      const error = LocalGalleryError(
        LocalGalleryErrorCode.refreshFailed,
        details: 'disk unavailable',
      );

      for (final l10n in localizations.values) {
        final message = error.localized(l10n);
        expect(message, isNotEmpty);
        expect(message, contains('disk unavailable'));
      }
    });

    test('bulk-operation errors are localized before display', () {
      const error = BulkOperationError(
        BulkOperationErrorCode.undoFailed,
        details: 'history unavailable',
      );

      expect(
        error.localized(localizations['en']!),
        'Undo failed: history unavailable',
      );
      expect(
        error.localized(localizations['ja']!),
        '元に戻せませんでした: history unavailable',
      );
      expect(error.localized(localizations['zh']!), '撤销失败：history unavailable');
    });

    test('category errors are localized before display', () {
      const error = CategoryOperationError(
        CategoryOperationErrorCode.invalidMove,
      );

      expect(
        error.localized(localizations['en']!),
        'A category cannot be moved under one of its descendants',
      );
      expect(error.localized(localizations['ja']!), '子孫カテゴリの下には移動できません');
      expect(error.localized(localizations['zh']!), '不能将分类移动到它的子孙分类下');
    });

    test('Vibe bulk errors are localized before display', () {
      const error = VibeBulkOperationError(
        VibeBulkOperationErrorCode.importFailed,
        itemName: 'sample.naiv4vibe',
        details: 'invalid payload',
      );

      expect(
        error.localized(localizations['en']!),
        'Failed to import Vibe from sample.naiv4vibe: invalid payload',
      );
      expect(
        error.localized(localizations['ja']!),
        'sample.naiv4vibe からの Vibe インポートに失敗しました: invalid payload',
      );
      expect(
        error.localized(localizations['zh']!),
        '从 sample.naiv4vibe 导入 Vibe 失败：invalid payload',
      );
    });
  });

  test('DIY labels and placeholders are generated for every locale', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final japanese = lookupAppLocalizations(const Locale('ja'));
    final chinese = lookupAppLocalizations(const Locale('zh'));

    expect(english.diy_branchDefaultName(2), 'Branch 2');
    expect(japanese.diy_branchDefaultName(2), '分岐 2');
    expect(chinese.diy_branchDefaultName(2), '分支 2');
    expect(japanese.statistics_monday, '月');
    expect(chinese.common_enabled, '已启用');
    expect(japanese.diy_positionCoordinates('50', '25'), '行: 50%、列: 25%');
    expect(
      english.diy_emphasisProbabilityHint('10.0'),
      'Each selected tag has a 10.0% chance of receiving emphasis brackets',
    );
    expect(english.networkError_requestFailed(429), 'Request failed (429)');
    expect(
      japanese.networkError_connectionTimeout,
      '接続がタイムアウトしました。ネットワーク接続を確認してください。',
    );
    expect(chinese.networkError_insufficientAnlas, 'Anlas 不足');
  });

  test('Vibe bulk and detail surfaces use generated translations', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final japanese = lookupAppLocalizations(const Locale('ja'));
    final chinese = lookupAppLocalizations(const Locale('zh'));

    expect(english.vibeBulkTag_selectedCount(3), '3 Vibes selected');
    expect(japanese.vibeBulkCategory_moveCount(2), '2 件の Vibe の移動先:');
    expect(chinese.vibeBulk_processingProgress(1, 4), '正在处理：1 / 4');
    expect(english.vibeDetail_timesUsed(5), '5 times');
    expect(japanese.vibeDetail_saveParameters, 'パラメーターを保存');
  });

  test('additional visible surfaces use generated translations', () {
    final english = lookupAppLocalizations(const Locale('en'));
    final japanese = lookupAppLocalizations(const Locale('ja'));
    final chinese = lookupAppLocalizations(const Locale('zh'));

    expect(english.editor_shiftEdges, 'Shift Edges');
    expect(japanese.editor_shiftEdges, 'エッジをシフト');
    expect(chinese.editor_shiftEdges, '扩展边缘');
    expect(
      english.imagePicker_fileSelectionFailed('denied'),
      'Failed to select file: denied',
    );
    expect(japanese.history_dragFilePreparing, 'ドラッグ用ファイルを準備しています...');
    expect(chinese.vibeDetail_releasePreviewImage, '释放以设置预览图');
    expect(english.router_pageNotFound('missing'), 'Page not found: missing');
  });
}

Map<String, dynamic> _readArb(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

List<String> _topLevelKeys(String path) {
  final keyPattern = RegExp(r'^ {0,2}"([^"]+)"\s*:');
  return File(path)
      .readAsLinesSync()
      .map(keyPattern.firstMatch)
      .whereType<RegExpMatch>()
      .map((match) => match.group(1)!)
      .toList();
}

Set<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}

Set<String> _metadataKeys(Map<String, dynamic> arb) {
  return arb.keys
      .where((key) => key.startsWith('@') && key != '@@locale')
      .toSet();
}

Set<String> _placeholders(String message) {
  return RegExp(
    r'\{([A-Za-z0-9_]+)\}',
  ).allMatches(message).map((match) => match.group(1)!).toSet();
}

Set<String> _productionLocalizationReferences() {
  final references = <String>{};
  final memberAccess = RegExp(r'\.\s*([A-Za-z_][A-Za-z0-9_]*)');
  final identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
  final localizationExtension = RegExp(
    r'extension\s+\w+\s+on\s+AppLocalizations\b',
  );
  final generatedLocalization = RegExp(
    r'(?:^|/)lib/l10n/app_localizations(?:_[a-z]+)?\.dart$',
  );

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final normalizedPath = entity.path.replaceAll('\\', '/');
    if (generatedLocalization.hasMatch(normalizedPath)) continue;

    final content = entity.readAsStringSync();
    references.addAll(
      memberAccess
          .allMatches(content)
          .map((match) => match.group(1)!)
          .where((name) => name.isNotEmpty),
    );

    // AppLocalizations extensions can access generated getters without a dot.
    if (localizationExtension.hasMatch(content)) {
      references.addAll(
        identifier.allMatches(content).map((match) => match.group(0)!),
      );
    }
  }

  return references;
}
