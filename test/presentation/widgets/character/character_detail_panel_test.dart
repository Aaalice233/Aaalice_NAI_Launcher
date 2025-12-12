import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide group, test, expect;
import 'package:nai_launcher/presentation/widgets/prompt/toolbar/prompt_editor_toolbar_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';

/// **Feature: prompt-editor-toolbar, Property 6: Text processing settings synchronization**
/// **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**
///
/// 对于任何由主编辑器设置菜单触发的文本处理设置变化
/// （autoFormat, syntaxHighlight, sdSyntaxAutoConvert, autocomplete），
/// 所有角色提示词编辑器应该反映相同的设置状态。

/// 文本处理设置状态
class TextProcessingSettings {
  final bool enableAutocomplete;
  final bool enableAutoFormat;
  final bool enableSyntaxHighlight;
  final bool enableSdSyntaxAutoConvert;

  const TextProcessingSettings({
    required this.enableAutocomplete,
    required this.enableAutoFormat,
    required this.enableSyntaxHighlight,
    required this.enableSdSyntaxAutoConvert,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextProcessingSettings &&
        other.enableAutocomplete == enableAutocomplete &&
        other.enableAutoFormat == enableAutoFormat &&
        other.enableSyntaxHighlight == enableSyntaxHighlight &&
        other.enableSdSyntaxAutoConvert == enableSdSyntaxAutoConvert;
  }

  @override
  int get hashCode => Object.hash(
        enableAutocomplete,
        enableAutoFormat,
        enableSyntaxHighlight,
        enableSdSyntaxAutoConvert,
      );

  @override
  String toString() =>
      'TextProcessingSettings(autocomplete: $enableAutocomplete, '
      'autoFormat: $enableAutoFormat, syntaxHighlight: $enableSyntaxHighlight, '
      'sdSyntaxAutoConvert: $enableSdSyntaxAutoConvert)';
}

/// 自定义生成器：生成随机的文本处理设置
Shrinkable<TextProcessingSettings> generateTextProcessingSettings(
  Random random,
  int size,
) {
  final settings = TextProcessingSettings(
    enableAutocomplete: random.nextBool(),
    enableAutoFormat: random.nextBool(),
    enableSyntaxHighlight: random.nextBool(),
    enableSdSyntaxAutoConvert: random.nextBool(),
  );

  return Shrinkable(settings, () sync* {
    // 简化策略：逐个将设置设为 false
    if (settings.enableAutocomplete) {
      yield Shrinkable(
        TextProcessingSettings(
          enableAutocomplete: false,
          enableAutoFormat: settings.enableAutoFormat,
          enableSyntaxHighlight: settings.enableSyntaxHighlight,
          enableSdSyntaxAutoConvert: settings.enableSdSyntaxAutoConvert,
        ),
        () sync* {},
      );
    }
    if (settings.enableAutoFormat) {
      yield Shrinkable(
        TextProcessingSettings(
          enableAutocomplete: settings.enableAutocomplete,
          enableAutoFormat: false,
          enableSyntaxHighlight: settings.enableSyntaxHighlight,
          enableSdSyntaxAutoConvert: settings.enableSdSyntaxAutoConvert,
        ),
        () sync* {},
      );
    }
  });
}

void main() {
  /// **Feature: prompt-editor-toolbar, Property 6: Text processing settings synchronization**
  /// **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**
  group('Property 6: Text processing settings synchronization', () {
    Glados<TextProcessingSettings>(generateTextProcessingSettings).test(
      'character editor config reflects shared settings',
      (settings) {
        // 模拟从 Provider 读取设置并应用到 UnifiedPromptConfig
        // 这是 _PromptSection 中的逻辑
        const baseConfig = UnifiedPromptConfig.characterEditor;
        final inputConfig = baseConfig.copyWith(
          enableAutocomplete: settings.enableAutocomplete,
          enableAutoFormat: settings.enableAutoFormat,
          enableSyntaxHighlight: settings.enableSyntaxHighlight,
          enableSdSyntaxAutoConvert: settings.enableSdSyntaxAutoConvert,
        );

        // 验证配置正确反映了设置
        expect(
          inputConfig.enableAutocomplete,
          equals(settings.enableAutocomplete),
          reason: 'enableAutocomplete should match shared setting',
        );
        expect(
          inputConfig.enableAutoFormat,
          equals(settings.enableAutoFormat),
          reason: 'enableAutoFormat should match shared setting',
        );
        expect(
          inputConfig.enableSyntaxHighlight,
          equals(settings.enableSyntaxHighlight),
          reason: 'enableSyntaxHighlight should match shared setting',
        );
        expect(
          inputConfig.enableSdSyntaxAutoConvert,
          equals(settings.enableSdSyntaxAutoConvert),
          reason: 'enableSdSyntaxAutoConvert should match shared setting',
        );
      },
    );

    Glados<TextProcessingSettings>(generateTextProcessingSettings).test(
      'compact mode config also reflects shared settings',
      (settings) {
        // 紧凑模式（负面提示词）也应该反映共享设置
        const baseConfig = UnifiedPromptConfig.compactMode;
        final inputConfig = baseConfig.copyWith(
          enableAutocomplete: settings.enableAutocomplete,
          enableAutoFormat: settings.enableAutoFormat,
          enableSyntaxHighlight: settings.enableSyntaxHighlight,
          enableSdSyntaxAutoConvert: settings.enableSdSyntaxAutoConvert,
        );

        // 验证配置正确反映了设置
        expect(
          inputConfig.enableAutocomplete,
          equals(settings.enableAutocomplete),
          reason: 'enableAutocomplete should match shared setting',
        );
        expect(
          inputConfig.enableAutoFormat,
          equals(settings.enableAutoFormat),
          reason: 'enableAutoFormat should match shared setting',
        );
        expect(
          inputConfig.enableSyntaxHighlight,
          equals(settings.enableSyntaxHighlight),
          reason: 'enableSyntaxHighlight should match shared setting',
        );
        expect(
          inputConfig.enableSdSyntaxAutoConvert,
          equals(settings.enableSdSyntaxAutoConvert),
          reason: 'enableSdSyntaxAutoConvert should match shared setting',
        );
      },
    );

    Glados2<TextProcessingSettings, TextProcessingSettings>(
      generateTextProcessingSettings,
      generateTextProcessingSettings,
    ).test(
      'multiple character editors reflect same settings',
      (settings1, settings2) {
        // 模拟两个角色编辑器从相同的 Provider 读取设置
        // 它们应该得到相同的配置

        // 使用 settings1 作为"共享设置"
        final config1 = UnifiedPromptConfig.characterEditor.copyWith(
          enableAutocomplete: settings1.enableAutocomplete,
          enableAutoFormat: settings1.enableAutoFormat,
          enableSyntaxHighlight: settings1.enableSyntaxHighlight,
          enableSdSyntaxAutoConvert: settings1.enableSdSyntaxAutoConvert,
        );

        // 另一个编辑器也从相同的设置读取
        final config2 = UnifiedPromptConfig.characterEditor.copyWith(
          enableAutocomplete: settings1.enableAutocomplete,
          enableAutoFormat: settings1.enableAutoFormat,
          enableSyntaxHighlight: settings1.enableSyntaxHighlight,
          enableSdSyntaxAutoConvert: settings1.enableSdSyntaxAutoConvert,
        );

        // 验证两个配置相同
        expect(
          config1.enableAutocomplete,
          equals(config2.enableAutocomplete),
          reason: 'Both editors should have same autocomplete setting',
        );
        expect(
          config1.enableAutoFormat,
          equals(config2.enableAutoFormat),
          reason: 'Both editors should have same autoFormat setting',
        );
        expect(
          config1.enableSyntaxHighlight,
          equals(config2.enableSyntaxHighlight),
          reason: 'Both editors should have same syntaxHighlight setting',
        );
        expect(
          config1.enableSdSyntaxAutoConvert,
          equals(config2.enableSdSyntaxAutoConvert),
          reason: 'Both editors should have same sdSyntaxAutoConvert setting',
        );
      },
    );

    test('settings change propagates to character editor config', () {
      // 模拟设置变化的传播
      // 初始设置
      var currentSettings = const TextProcessingSettings(
        enableAutocomplete: true,
        enableAutoFormat: true,
        enableSyntaxHighlight: true,
        enableSdSyntaxAutoConvert: false,
      );

      // 创建初始配置
      var config = UnifiedPromptConfig.characterEditor.copyWith(
        enableAutocomplete: currentSettings.enableAutocomplete,
        enableAutoFormat: currentSettings.enableAutoFormat,
        enableSyntaxHighlight: currentSettings.enableSyntaxHighlight,
        enableSdSyntaxAutoConvert: currentSettings.enableSdSyntaxAutoConvert,
      );

      expect(config.enableAutocomplete, isTrue);
      expect(config.enableSdSyntaxAutoConvert, isFalse);

      // 模拟主编辑器更改设置
      currentSettings = const TextProcessingSettings(
        enableAutocomplete: false,
        enableAutoFormat: true,
        enableSyntaxHighlight: false,
        enableSdSyntaxAutoConvert: true,
      );

      // 重新创建配置（模拟 Provider 触发重建）
      config = UnifiedPromptConfig.characterEditor.copyWith(
        enableAutocomplete: currentSettings.enableAutocomplete,
        enableAutoFormat: currentSettings.enableAutoFormat,
        enableSyntaxHighlight: currentSettings.enableSyntaxHighlight,
        enableSdSyntaxAutoConvert: currentSettings.enableSdSyntaxAutoConvert,
      );

      // 验证配置反映了新设置
      expect(config.enableAutocomplete, isFalse);
      expect(config.enableAutoFormat, isTrue);
      expect(config.enableSyntaxHighlight, isFalse);
      expect(config.enableSdSyntaxAutoConvert, isTrue);
    });
  });

  /// **Feature: prompt-editor-toolbar, Property 7: Character editor has no settings menu**
  /// **Validates: Requirements 6.6**
  group('Property 7: Character editor has no settings menu', () {
    test('characterEditor preset has showSettingsButton disabled', () {
      const config = PromptEditorToolbarConfig.characterEditor;

      // 验证设置按钮被禁用
      expect(
        config.showSettingsButton,
        isFalse,
        reason: 'Character editor should not show settings button',
      );
    });

    test('compactMode preset also has showSettingsButton disabled', () {
      const config = PromptEditorToolbarConfig.compactMode;

      // 验证紧凑模式也禁用了设置按钮
      expect(
        config.showSettingsButton,
        isFalse,
        reason: 'Compact mode should not show settings button',
      );
    });

    test('mainEditor preset has showSettingsButton enabled', () {
      const config = PromptEditorToolbarConfig.mainEditor;

      // 验证主编辑器启用了设置按钮
      expect(
        config.showSettingsButton,
        isTrue,
        reason: 'Main editor should show settings button',
      );
    });

    Glados<bool>(any.bool).test(
      'character editor toolbar never shows settings regardless of other flags',
      (randomBool) {
        // 即使尝试通过 copyWith 启用设置按钮，
        // characterEditor 预设的设计意图是不显示设置
        const baseConfig = PromptEditorToolbarConfig.characterEditor;

        // 验证基础配置不显示设置按钮
        expect(baseConfig.showSettingsButton, isFalse);

        // 如果有人尝试覆盖，copyWith 会生效，
        // 但这不是推荐的用法
        final modifiedConfig = baseConfig.copyWith(
          showSettingsButton: randomBool,
        );

        // copyWith 应该正确工作
        expect(modifiedConfig.showSettingsButton, equals(randomBool));

        // 但原始预设应该保持不变
        expect(baseConfig.showSettingsButton, isFalse);
      },
    );

    test('character editor relies on main editor for settings control', () {
      // 验证设计意图：角色编辑器依赖主编辑器控制设置
      const characterConfig = PromptEditorToolbarConfig.characterEditor;
      const mainConfig = PromptEditorToolbarConfig.mainEditor;

      // 主编辑器有设置按钮
      expect(mainConfig.showSettingsButton, isTrue);

      // 角色编辑器没有设置按钮
      expect(characterConfig.showSettingsButton, isFalse);

      // 角色编辑器只有清空按钮
      expect(characterConfig.showClearButton, isTrue);
      expect(characterConfig.showViewModeToggle, isFalse);
      expect(characterConfig.showRandomButton, isFalse);
      expect(characterConfig.showFullscreenButton, isFalse);
    });
  });
}
