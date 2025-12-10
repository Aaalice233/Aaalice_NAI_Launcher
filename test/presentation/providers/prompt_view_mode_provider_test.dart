import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide group, test, expect, setUpAll, tearDownAll, setUp;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/presentation/providers/prompt_view_mode_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart'
    show PromptViewMode;

/// **Feature: prompt-editor-toolbar, Property 3: View mode state synchronization**
/// **Validates: Requirements 2.3, 4.1, 4.4**
///
/// 对于任何由主编辑器触发的视图模式变化，所有提示词输入（主界面和角色）
/// 应该反映相同的视图模式状态。

void main() {
  late Box settingsBox;

  setUpAll(() async {
    // 初始化 Hive 用于测试
    Hive.init('./test_hive');
    settingsBox = await Hive.openBox('settings');
  });

  setUp(() async {
    // 每个测试前清除存储状态，确保测试隔离
    await settingsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('Property 3: View mode state synchronization', () {
    test('initial view mode is text when storage is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final viewMode = container.read(promptViewModeNotifierProvider);
      expect(viewMode, equals(PromptViewMode.text));
    });

    test('setViewMode updates state correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 设置为 tags 模式
      await container
          .read(promptViewModeNotifierProvider.notifier)
          .setViewMode(PromptViewMode.tags);

      expect(
        container.read(promptViewModeNotifierProvider),
        equals(PromptViewMode.tags),
      );

      // 设置回 text 模式
      await container
          .read(promptViewModeNotifierProvider.notifier)
          .setViewMode(PromptViewMode.text);

      expect(
        container.read(promptViewModeNotifierProvider),
        equals(PromptViewMode.text),
      );
    });

    test('toggle switches between text and tags modes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 初始状态应该是 text
      expect(
        container.read(promptViewModeNotifierProvider),
        equals(PromptViewMode.text),
      );

      // 切换到 tags
      await container.read(promptViewModeNotifierProvider.notifier).toggle();
      expect(
        container.read(promptViewModeNotifierProvider),
        equals(PromptViewMode.tags),
      );

      // 切换回 text
      await container.read(promptViewModeNotifierProvider.notifier).toggle();
      expect(
        container.read(promptViewModeNotifierProvider),
        equals(PromptViewMode.text),
      );
    });

    test('multiple consumers see the same state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 模拟多个消费者读取状态
      final consumer1 = container.read(promptViewModeNotifierProvider);
      final consumer2 = container.read(promptViewModeNotifierProvider);

      expect(consumer1, equals(consumer2));

      // 更新状态
      await container
          .read(promptViewModeNotifierProvider.notifier)
          .setViewMode(PromptViewMode.tags);

      // 所有消费者应该看到相同的新状态
      final newConsumer1 = container.read(promptViewModeNotifierProvider);
      final newConsumer2 = container.read(promptViewModeNotifierProvider);

      expect(newConsumer1, equals(PromptViewMode.tags));
      expect(newConsumer2, equals(PromptViewMode.tags));
      expect(newConsumer1, equals(newConsumer2));
    });

    // 属性测试：验证视图模式切换的幂等性
    Glados<int>(any.intInRange(0, 20)).test(
      'toggle is idempotent after even number of calls',
      (toggleCount) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initialMode = container.read(promptViewModeNotifierProvider);

        // 执行偶数次切换
        final evenCount = toggleCount * 2;
        for (var i = 0; i < evenCount; i++) {
          await container
              .read(promptViewModeNotifierProvider.notifier)
              .toggle();
        }

        // 偶数次切换后应该回到初始状态
        expect(
          container.read(promptViewModeNotifierProvider),
          equals(initialMode),
          reason: 'After $evenCount toggles, should return to initial state',
        );
      },
    );

    // 属性测试：验证 setViewMode 的幂等性
    Glados<PromptViewMode>(any.choose(PromptViewMode.values)).test(
      'setViewMode is idempotent',
      (mode) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // 设置一次
        await container
            .read(promptViewModeNotifierProvider.notifier)
            .setViewMode(mode);
        final stateAfterFirst = container.read(promptViewModeNotifierProvider);

        // 设置第二次（相同值）
        await container
            .read(promptViewModeNotifierProvider.notifier)
            .setViewMode(mode);
        final stateAfterSecond = container.read(promptViewModeNotifierProvider);

        expect(
          stateAfterFirst,
          equals(stateAfterSecond),
          reason: 'Setting same mode twice should result in same state',
        );
        expect(
          stateAfterSecond,
          equals(mode),
          reason: 'State should equal the set mode',
        );
      },
    );

    // 属性测试：验证状态变化的一致性
    Glados2<PromptViewMode, PromptViewMode>(
      any.choose(PromptViewMode.values),
      any.choose(PromptViewMode.values),
    ).test(
      'state changes are consistent across multiple consumers',
      (mode1, mode2) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // 设置第一个模式
        await container
            .read(promptViewModeNotifierProvider.notifier)
            .setViewMode(mode1);

        // 多个消费者应该看到相同状态
        expect(
          container.read(promptViewModeNotifierProvider),
          equals(mode1),
        );

        // 设置第二个模式
        await container
            .read(promptViewModeNotifierProvider.notifier)
            .setViewMode(mode2);

        // 所有消费者应该看到新状态
        expect(
          container.read(promptViewModeNotifierProvider),
          equals(mode2),
        );
      },
    );
  });
}
