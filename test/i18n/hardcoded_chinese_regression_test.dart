import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

void main() {
  test('Japanese locale is generated and available', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('ja')));

    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(l10n.settings_language, '言語');
    expect(l10n.settings_languageJapanese, '日本語');
    expect(l10n.common_cancel, isNot('Cancel'));
  });

  test('selected visible surfaces do not hardcode Chinese strings', () {
    final files = [
      'lib/presentation/widgets/common/themed_confirm_dialog.dart',
      'lib/presentation/widgets/common/glass_dialog.dart',
      'lib/presentation/widgets/common/themed_input.dart',
      'lib/core/services/warmup_task_scheduler.dart',
      'lib/core/enums/warmup_phase.dart',
      'lib/presentation/providers/warmup_provider.dart',
      'lib/presentation/screens/splash/splash_screen.dart',
      'lib/core/shortcuts/default_shortcuts.dart',
      'lib/presentation/widgets/shortcuts/shortcut_help_dialog.dart',
      'lib/presentation/widgets/shortcuts/shortcut_binding_editor.dart',
      'lib/presentation/providers/gallery_category_provider.dart',
      'lib/presentation/providers/vibe_library_category_provider.dart',
      'lib/data/models/vibe/vibe_empty_state_info.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_library_empty_view.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_library_content_view.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_import_naming_dialog.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_export_dialog_advanced.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_export_dialog.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_detail_viewer.dart',
      'lib/presentation/screens/vibe_library/widgets/vibe_bundle_import_dialog.dart',
      'lib/presentation/widgets/common/save_vibe_dialog.dart',
      'lib/presentation/widgets/common/save_as_preset_dialog.dart',
      'lib/presentation/widgets/common/add_to_library_dialog.dart',
      'lib/presentation/widgets/common/image_detail/components/detail_top_bar.dart',
      'lib/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart',
      'lib/presentation/widgets/common/image_detail/components/prompt_section.dart',
      'lib/presentation/widgets/common/image_detail/components/vibe_section.dart',
      'lib/presentation/widgets/queue/queue_export_dialog.dart',
      'lib/presentation/widgets/gallery_filter_panel.dart',
      'lib/presentation/widgets/common/pagination_bar.dart',
      'lib/presentation/widgets/prompt/diy/dialogs/diy_guide_dialog.dart',
      'lib/presentation/widgets/prompt/diy/dialogs/nai_rules_dialog.dart',
      'lib/presentation/widgets/prompt/comfyui_import_dialog.dart',
      'lib/presentation/widgets/prompt/random_manager/danbooru_preview_content.dart',
    ];

    final violations = <String>[];
    final chinese = RegExp(r'[\u4e00-\u9fff]');
    final stringLiteral = RegExp(
      r'''(["'])(?:(?!\1).)*[\u4e00-\u9fff](?:(?!\1).)*\1''',
    );

    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path should exist');

      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('/*')) {
          continue;
        }
        if (_isLoggingLine(lines, index)) {
          continue;
        }

        if (!chinese.hasMatch(line) || !stringLiteral.hasMatch(line)) {
          continue;
        }

        if (_isAllowedCompatibilityLine(path, line)) {
          continue;
        }

        violations.add('${file.path}:${index + 1}: ${line.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Move visible Chinese text into ARB/l10n keys or explicit legacy compatibility maps.',
    );
  });
}

bool _isLoggingLine(List<String> lines, int index) {
  final line = lines[index];
  if (line.contains('AppLogger.') || line.contains('debugPrint(')) {
    return true;
  }

  final lookbehindStart = index - 4 < 0 ? 0 : index - 4;
  for (var i = index - 1; i >= lookbehindStart; i -= 1) {
    final previous = lines[i];
    if (previous.contains('AppLogger.') || previous.contains('debugPrint(')) {
      return true;
    }
    if (previous.trimRight().endsWith(';')) {
      break;
    }
  }

  return false;
}

bool _isAllowedCompatibilityLine(String path, String line) {
  if (path.endsWith('splash_screen.dart')) {
    return line.contains('contains(') || line.contains('RegExp(');
  }

  return false;
}
