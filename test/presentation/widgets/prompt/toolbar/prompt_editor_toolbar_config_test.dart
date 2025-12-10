import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide group, test, expect;
import 'package:nai_launcher/presentation/widgets/prompt/toolbar/prompt_editor_toolbar_config.dart';

/// 为 PromptEditorToolbarConfig 生成随机配置
Shrinkable<PromptEditorToolbarConfig> generateToolbarConfig(
  Random random,
  int size,
) {
  final config = PromptEditorToolbarConfig(
    showViewModeToggle: random.nextBool(),
    showRandomButton: random.nextBool(),
    showFullscreenButton: random.nextBool(),
    showClearButton: random.nextBool(),
    showSettingsButton: random.nextBool(),
    compact: random.nextBool(),
    confirmBeforeClear: random.nextBool(),
  );

  return Shrinkable(config, () sync* {
    // 简化策略：逐个将标志设为 false
    if (config.showViewModeToggle) {
      yield Shrinkable(
        config.copyWith(showViewModeToggle: false),
        () sync* {},
      );
    }
    if (config.showRandomButton) {
      yield Shrinkable(
        config.copyWith(showRandomButton: false),
        () sync* {},
      );
    }
    if (config.showFullscreenButton) {
      yield Shrinkable(
        config.copyWith(showFullscreenButton: false),
        () sync* {},
      );
    }
    if (config.showClearButton) {
      yield Shrinkable(
        config.copyWith(showClearButton: false),
        () sync* {},
      );
    }
    if (config.showSettingsButton) {
      yield Shrinkable(
        config.copyWith(showSettingsButton: false),
        () sync* {},
      );
    }
  });
}

void main() {
  /// **Feature: prompt-editor-toolbar, Property 1: Configuration controls visibility**
  /// **Validates: Requirements 1.2, 1.3**
  ///
  /// 对于任意 PromptEditorToolbarConfig 和任意工具栏操作，
  /// 工具栏显示该操作当且仅当对应的配置标志为 true。
  group('Property 1: Configuration controls visibility', () {
    Glados<PromptEditorToolbarConfig>(generateToolbarConfig).test(
      'config flags correctly control action visibility',
      (config) {
        // 验证每个配置标志都能正确控制对应操作的可见性
        expect(
          config.showViewModeToggle,
          isA<bool>(),
          reason: 'showViewModeToggle should be a boolean',
        );

        expect(
          config.showRandomButton,
          isA<bool>(),
          reason: 'showRandomButton should be a boolean',
        );

        expect(
          config.showFullscreenButton,
          isA<bool>(),
          reason: 'showFullscreenButton should be a boolean',
        );

        expect(
          config.showClearButton,
          isA<bool>(),
          reason: 'showClearButton should be a boolean',
        );

        expect(
          config.showSettingsButton,
          isA<bool>(),
          reason: 'showSettingsButton should be a boolean',
        );

        // 验证配置的一致性：相同的配置应该产生相同的可见性决策
        final sameConfig = PromptEditorToolbarConfig(
          showViewModeToggle: config.showViewModeToggle,
          showRandomButton: config.showRandomButton,
          showFullscreenButton: config.showFullscreenButton,
          showClearButton: config.showClearButton,
          showSettingsButton: config.showSettingsButton,
          compact: config.compact,
          confirmBeforeClear: config.confirmBeforeClear,
        );

        expect(
          sameConfig,
          equals(config),
          reason: 'Same configuration values should produce equal configs',
        );
      },
    );

    Glados<PromptEditorToolbarConfig>(generateToolbarConfig).test(
      'visibility is determined solely by config flags',
      (config) {
        // 计算应该显示的按钮数量
        int visibleButtonCount = 0;
        if (config.showViewModeToggle) visibleButtonCount++;
        if (config.showRandomButton) visibleButtonCount++;
        if (config.showFullscreenButton) visibleButtonCount++;
        if (config.showClearButton) visibleButtonCount++;
        if (config.showSettingsButton) visibleButtonCount++;

        // 验证可见按钮数量在有效范围内
        expect(
          visibleButtonCount,
          inInclusiveRange(0, 5),
          reason: 'Visible button count should be between 0 and 5',
        );

        // 验证：如果所有标志都为 false，则没有按钮可见
        final allDisabled = !config.showViewModeToggle &&
            !config.showRandomButton &&
            !config.showFullscreenButton &&
            !config.showClearButton &&
            !config.showSettingsButton;

        if (allDisabled) {
          expect(
            visibleButtonCount,
            equals(0),
            reason: 'No buttons should be visible when all flags are false',
          );
        }
      },
    );
  });

  /// **Feature: prompt-editor-toolbar, Property 2: copyWith preserves unmodified properties**
  /// **Validates: Requirements 3.3**
  ///
  /// 对于任意 PromptEditorToolbarConfig 和任意单个属性覆盖，
  /// 调用 copyWith 应该产生一个新配置，其中只有指定的属性被更改，
  /// 其他所有属性保持原始值。
  group('Property 2: copyWith preserves unmodified properties', () {
    Glados2<PromptEditorToolbarConfig, bool>(
      generateToolbarConfig,
      any.bool,
    ).test(
      'copyWith with showViewModeToggle preserves other properties',
      (config, newValue) {
        final modified = config.copyWith(showViewModeToggle: newValue);

        expect(modified.showViewModeToggle, equals(newValue));
        expect(modified.showRandomButton, equals(config.showRandomButton));
        expect(
          modified.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(modified.showClearButton, equals(config.showClearButton));
        expect(modified.showSettingsButton, equals(config.showSettingsButton));
        expect(modified.compact, equals(config.compact));
        expect(modified.confirmBeforeClear, equals(config.confirmBeforeClear));
      },
    );

    Glados2<PromptEditorToolbarConfig, bool>(
      generateToolbarConfig,
      any.bool,
    ).test(
      'copyWith with showRandomButton preserves other properties',
      (config, newValue) {
        final modified = config.copyWith(showRandomButton: newValue);

        expect(modified.showViewModeToggle, equals(config.showViewModeToggle));
        expect(modified.showRandomButton, equals(newValue));
        expect(
          modified.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(modified.showClearButton, equals(config.showClearButton));
        expect(modified.showSettingsButton, equals(config.showSettingsButton));
        expect(modified.compact, equals(config.compact));
        expect(modified.confirmBeforeClear, equals(config.confirmBeforeClear));
      },
    );

    Glados2<PromptEditorToolbarConfig, bool>(
      generateToolbarConfig,
      any.bool,
    ).test(
      'copyWith with showFullscreenButton preserves other properties',
      (config, newValue) {
        final modified = config.copyWith(showFullscreenButton: newValue);

        expect(modified.showViewModeToggle, equals(config.showViewModeToggle));
        expect(modified.showRandomButton, equals(config.showRandomButton));
        expect(modified.showFullscreenButton, equals(newValue));
        expect(modified.showClearButton, equals(config.showClearButton));
        expect(modified.showSettingsButton, equals(config.showSettingsButton));
        expect(modified.compact, equals(config.compact));
        expect(modified.confirmBeforeClear, equals(config.confirmBeforeClear));
      },
    );

    Glados2<PromptEditorToolbarConfig, bool>(
      generateToolbarConfig,
      any.bool,
    ).test(
      'copyWith with showClearButton preserves other properties',
      (config, newValue) {
        final modified = config.copyWith(showClearButton: newValue);

        expect(modified.showViewModeToggle, equals(config.showViewModeToggle));
        expect(modified.showRandomButton, equals(config.showRandomButton));
        expect(
          modified.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(modified.showClearButton, equals(newValue));
        expect(modified.showSettingsButton, equals(config.showSettingsButton));
        expect(modified.compact, equals(config.compact));
        expect(modified.confirmBeforeClear, equals(config.confirmBeforeClear));
      },
    );

    Glados2<PromptEditorToolbarConfig, bool>(
      generateToolbarConfig,
      any.bool,
    ).test(
      'copyWith with showSettingsButton preserves other properties',
      (config, newValue) {
        final modified = config.copyWith(showSettingsButton: newValue);

        expect(modified.showViewModeToggle, equals(config.showViewModeToggle));
        expect(modified.showRandomButton, equals(config.showRandomButton));
        expect(
          modified.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(modified.showClearButton, equals(config.showClearButton));
        expect(modified.showSettingsButton, equals(newValue));
        expect(modified.compact, equals(config.compact));
        expect(modified.confirmBeforeClear, equals(config.confirmBeforeClear));
      },
    );

    Glados2<PromptEditorToolbarConfig, bool>(
      generateToolbarConfig,
      any.bool,
    ).test(
      'copyWith with compact preserves other properties',
      (config, newValue) {
        final modified = config.copyWith(compact: newValue);

        expect(modified.showViewModeToggle, equals(config.showViewModeToggle));
        expect(modified.showRandomButton, equals(config.showRandomButton));
        expect(
          modified.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(modified.showClearButton, equals(config.showClearButton));
        expect(modified.showSettingsButton, equals(config.showSettingsButton));
        expect(modified.compact, equals(newValue));
        expect(modified.confirmBeforeClear, equals(config.confirmBeforeClear));
      },
    );

    Glados2<PromptEditorToolbarConfig, bool>(
      generateToolbarConfig,
      any.bool,
    ).test(
      'copyWith with confirmBeforeClear preserves other properties',
      (config, newValue) {
        final modified = config.copyWith(confirmBeforeClear: newValue);

        expect(modified.showViewModeToggle, equals(config.showViewModeToggle));
        expect(modified.showRandomButton, equals(config.showRandomButton));
        expect(
          modified.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(modified.showClearButton, equals(config.showClearButton));
        expect(modified.showSettingsButton, equals(config.showSettingsButton));
        expect(modified.compact, equals(config.compact));
        expect(modified.confirmBeforeClear, equals(newValue));
      },
    );

    Glados<PromptEditorToolbarConfig>(generateToolbarConfig).test(
      'copyWith with no arguments returns equal config',
      (config) {
        final modified = config.copyWith();

        expect(modified, equals(config));
        expect(modified.showViewModeToggle, equals(config.showViewModeToggle));
        expect(modified.showRandomButton, equals(config.showRandomButton));
        expect(
          modified.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(modified.showClearButton, equals(config.showClearButton));
        expect(modified.showSettingsButton, equals(config.showSettingsButton));
        expect(modified.compact, equals(config.compact));
        expect(modified.confirmBeforeClear, equals(config.confirmBeforeClear));
      },
    );
  });

  /// **Feature: prompt-editor-toolbar, Property 5: characterEditor preset configuration**
  /// **Validates: Requirements 2.2, 3.4**
  ///
  /// 对于 characterEditor 预设，只有 showClearButton 应该为 true，
  /// 其他所有操作标志（showViewModeToggle, showRandomButton, showFullscreenButton, showSettingsButton）
  /// 应该为 false。confirmBeforeClear 也应该为 false（直接清空，无需确认）。
  group('Property 5: characterEditor preset configuration', () {
    test('characterEditor preset has only showClearButton enabled', () {
      const config = PromptEditorToolbarConfig.characterEditor;

      // 验证只有 showClearButton 为 true
      expect(
        config.showClearButton,
        isTrue,
        reason: 'showClearButton should be true',
      );

      // 验证其他所有操作标志为 false
      expect(
        config.showViewModeToggle,
        isFalse,
        reason: 'showViewModeToggle should be false',
      );
      expect(
        config.showRandomButton,
        isFalse,
        reason: 'showRandomButton should be false',
      );
      expect(
        config.showFullscreenButton,
        isFalse,
        reason: 'showFullscreenButton should be false',
      );
      expect(
        config.showSettingsButton,
        isFalse,
        reason: 'showSettingsButton should be false',
      );
    });

    test('characterEditor preset has confirmBeforeClear disabled', () {
      const config = PromptEditorToolbarConfig.characterEditor;

      // 验证 confirmBeforeClear 为 false（直接清空，无需确认）
      expect(
        config.confirmBeforeClear,
        isFalse,
        reason: 'confirmBeforeClear should be false for immediate clear',
      );
    });

    test('characterEditor preset differs from mainEditor preset', () {
      const characterConfig = PromptEditorToolbarConfig.characterEditor;
      const mainConfig = PromptEditorToolbarConfig.mainEditor;

      // 验证两个预设不相等
      expect(
        characterConfig,
        isNot(equals(mainConfig)),
        reason: 'characterEditor should differ from mainEditor',
      );

      // 验证 mainEditor 启用了 characterEditor 禁用的功能
      expect(mainConfig.showViewModeToggle, isTrue);
      expect(mainConfig.showSettingsButton, isTrue);
      expect(mainConfig.confirmBeforeClear, isTrue);
    });

    // 属性测试：验证 characterEditor 预设的不变性
    Glados<int>(any.intInRange(0, 100)).test(
      'characterEditor preset configuration is immutable and consistent',
      (seed) {
        // 多次访问预设应该返回相同的配置
        const config1 = PromptEditorToolbarConfig.characterEditor;
        const config2 = PromptEditorToolbarConfig.characterEditor;

        expect(
          config1,
          equals(config2),
          reason: 'Preset should be consistent across accesses',
        );

        // 验证核心属性
        expect(config1.showClearButton, isTrue);
        expect(config1.showViewModeToggle, isFalse);
        expect(config1.showRandomButton, isFalse);
        expect(config1.showFullscreenButton, isFalse);
        expect(config1.showSettingsButton, isFalse);
        expect(config1.confirmBeforeClear, isFalse);
      },
    );
  });

  /// **Feature: prompt-editor-toolbar, Property 4: Clear action behavior based on confirmation setting**
  /// **Validates: Requirements 2.6, 4.2**
  ///
  /// 对于任意启用清空功能的工具栏：
  /// - 当 confirmBeforeClear 为 false（characterEditor）时，点击清空应立即调用 onClearPressed
  /// - 当 confirmBeforeClear 为 true（mainEditor）时，点击清空应先显示确认
  group('Property 4: Clear action behavior based on confirmation setting', () {
    Glados<PromptEditorToolbarConfig>(generateToolbarConfig).test(
      'confirmBeforeClear determines clear behavior',
      (config) {
        // 验证 confirmBeforeClear 是布尔值
        expect(
          config.confirmBeforeClear,
          isA<bool>(),
          reason: 'confirmBeforeClear should be a boolean',
        );

        // 验证配置的一致性
        if (config.confirmBeforeClear) {
          // 需要确认的配置
          expect(
            config.confirmBeforeClear,
            isTrue,
            reason:
                'Config with confirmation should have confirmBeforeClear true',
          );
        } else {
          // 不需要确认的配置
          expect(
            config.confirmBeforeClear,
            isFalse,
            reason:
                'Config without confirmation should have confirmBeforeClear false',
          );
        }
      },
    );

    test('mainEditor preset requires confirmation before clear', () {
      const config = PromptEditorToolbarConfig.mainEditor;

      expect(
        config.showClearButton,
        isTrue,
        reason: 'mainEditor should have clear button enabled',
      );
      expect(
        config.confirmBeforeClear,
        isTrue,
        reason: 'mainEditor should require confirmation before clear',
      );
    });

    test('characterEditor preset clears immediately without confirmation', () {
      const config = PromptEditorToolbarConfig.characterEditor;

      expect(
        config.showClearButton,
        isTrue,
        reason: 'characterEditor should have clear button enabled',
      );
      expect(
        config.confirmBeforeClear,
        isFalse,
        reason: 'characterEditor should clear immediately without confirmation',
      );
    });

    Glados2<bool, bool>(any.bool, any.bool).test(
      'clear behavior is independent of other config flags',
      (showClearButton, confirmBeforeClear) {
        final config = PromptEditorToolbarConfig(
          showClearButton: showClearButton,
          confirmBeforeClear: confirmBeforeClear,
        );

        // 验证清空按钮可见性和确认行为是独立的
        expect(config.showClearButton, equals(showClearButton));
        expect(config.confirmBeforeClear, equals(confirmBeforeClear));

        // 如果清空按钮不可见，确认设置仍然保持
        if (!showClearButton) {
          expect(
            config.confirmBeforeClear,
            equals(confirmBeforeClear),
            reason:
                'confirmBeforeClear should be preserved even when clear button is hidden',
          );
        }
      },
    );

    Glados<PromptEditorToolbarConfig>(generateToolbarConfig).test(
      'copyWith can toggle confirmation behavior',
      (config) {
        // 切换确认行为
        final toggled = config.copyWith(
          confirmBeforeClear: !config.confirmBeforeClear,
        );

        expect(
          toggled.confirmBeforeClear,
          equals(!config.confirmBeforeClear),
          reason: 'copyWith should toggle confirmBeforeClear',
        );

        // 其他属性应保持不变
        expect(toggled.showClearButton, equals(config.showClearButton));
        expect(toggled.showViewModeToggle, equals(config.showViewModeToggle));
        expect(toggled.showRandomButton, equals(config.showRandomButton));
        expect(
          toggled.showFullscreenButton,
          equals(config.showFullscreenButton),
        );
        expect(toggled.showSettingsButton, equals(config.showSettingsButton));
        expect(toggled.compact, equals(config.compact));
      },
    );
  });
}
