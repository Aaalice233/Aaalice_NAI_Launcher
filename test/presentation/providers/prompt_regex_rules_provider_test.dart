import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/prompt/prompt_regex_rule.dart';
import 'package:nai_launcher/presentation/providers/prompt_regex_rules_provider.dart';

String _encodeRule({
  required String id,
  String pattern = 'a',
  String replacement = 'b',
  bool enabled = true,
  int sortOrder = 0,
}) {
  return jsonEncode(
    PromptRegexRule(
      id: id,
      pattern: pattern,
      replacement: replacement,
      enabled: enabled,
      sortOrder: sortOrder,
    ).toJson(),
  );
}

ProviderContainer _buildContainer(_MemoryLocalStorageService storage) {
  final container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
  );
  addTearDown(container.dispose);
  return container;
}

List<String> _storedIds(_MemoryLocalStorageService storage) {
  final raw = storage.values[StorageKeys.promptRegexRules] as List<dynamic>?;
  if (raw == null) return const [];
  return raw
      .cast<String>()
      .map((item) => jsonDecode(item) as Map<String, dynamic>)
      .map((json) => json['id'] as String)
      .toList();
}

void main() {
  group('PromptRegexRules 加载', () {
    test('存储为空时返回空列表', () {
      final container = _buildContainer(_MemoryLocalStorageService());

      expect(container.read(promptRegexRulesProvider), isEmpty);
    });

    test('按 sortOrder 排序而不是存储顺序', () {
      final storage = _MemoryLocalStorageService(
        initialValues: {
          StorageKeys.promptRegexRules: [
            _encodeRule(id: 'second', sortOrder: 1),
            _encodeRule(id: 'first', sortOrder: 0),
          ],
        },
      );
      final container = _buildContainer(storage);

      expect(container.read(promptRegexRulesProvider).map((rule) => rule.id), [
        'first',
        'second',
      ]);
    });

    test('单条损坏的 JSON 被跳过，其余规则照常加载', () {
      final storage = _MemoryLocalStorageService(
        initialValues: {
          StorageKeys.promptRegexRules: [
            'not-json',
            _encodeRule(id: 'ok', sortOrder: 0),
          ],
        },
      );
      final container = _buildContainer(storage);

      expect(container.read(promptRegexRulesProvider).map((rule) => rule.id), [
        'ok',
      ]);
    });
  });

  group('PromptRegexRules 变更', () {
    test('add 追加到末尾并持久化', () {
      final storage = _MemoryLocalStorageService();
      final container = _buildContainer(storage);
      final notifier = container.read(promptRegexRulesProvider.notifier);

      notifier.add(const PromptRegexRule(id: 'x', pattern: 'a'));
      notifier.add(const PromptRegexRule(id: 'y', pattern: 'b'));

      final rules = container.read(promptRegexRulesProvider);
      expect(rules.map((rule) => rule.pattern), ['a', 'b']);
      expect(rules.map((rule) => rule.sortOrder), [0, 1]);
      expect(_storedIds(storage), hasLength(2));
    });

    test('update 按 id 覆盖并保持位置', () {
      final storage = _MemoryLocalStorageService(
        initialValues: {
          StorageKeys.promptRegexRules: [
            _encodeRule(id: 'a', pattern: 'one', sortOrder: 0),
            _encodeRule(id: 'b', pattern: 'two', sortOrder: 1),
          ],
        },
      );
      final container = _buildContainer(storage);
      final notifier = container.read(promptRegexRulesProvider.notifier);

      final target = container
          .read(promptRegexRulesProvider)
          .firstWhere((rule) => rule.id == 'a');
      notifier.update(target.copyWith(pattern: 'updated'));

      expect(
        container.read(promptRegexRulesProvider).map((rule) => rule.pattern),
        ['updated', 'two'],
      );
    });

    test('remove 删除并重新分配 sortOrder', () {
      final storage = _MemoryLocalStorageService(
        initialValues: {
          StorageKeys.promptRegexRules: [
            _encodeRule(id: 'a', sortOrder: 0),
            _encodeRule(id: 'b', sortOrder: 1),
            _encodeRule(id: 'c', sortOrder: 2),
          ],
        },
      );
      final container = _buildContainer(storage);

      container.read(promptRegexRulesProvider.notifier).remove('b');

      final rules = container.read(promptRegexRulesProvider);
      expect(rules.map((rule) => rule.id), ['a', 'c']);
      expect(rules.map((rule) => rule.sortOrder), [0, 1]);
      expect(_storedIds(storage), ['a', 'c']);
    });

    test('toggleEnabled 只影响目标规则', () {
      final storage = _MemoryLocalStorageService(
        initialValues: {
          StorageKeys.promptRegexRules: [
            _encodeRule(id: 'a', sortOrder: 0),
            _encodeRule(id: 'b', sortOrder: 1),
          ],
        },
      );
      final container = _buildContainer(storage);

      container.read(promptRegexRulesProvider.notifier).toggleEnabled('a');

      final rules = container.read(promptRegexRulesProvider);
      expect(rules.firstWhere((rule) => rule.id == 'a').enabled, isFalse);
      expect(rules.firstWhere((rule) => rule.id == 'b').enabled, isTrue);
    });

    test('reorder 使用 onReorderItem 的已修正索引', () {
      final storage = _MemoryLocalStorageService(
        initialValues: {
          StorageKeys.promptRegexRules: [
            _encodeRule(id: 'a', sortOrder: 0),
            _encodeRule(id: 'b', sortOrder: 1),
            _encodeRule(id: 'c', sortOrder: 2),
          ],
        },
      );
      final container = _buildContainer(storage);
      final notifier = container.read(promptRegexRulesProvider.notifier);

      // 把第一条拖到末尾：移除后目标下标为 2
      notifier.reorder(0, 2);

      expect(container.read(promptRegexRulesProvider).map((rule) => rule.id), [
        'b',
        'c',
        'a',
      ]);

      // 再把末尾拖回开头
      notifier.reorder(2, 0);

      expect(container.read(promptRegexRulesProvider).map((rule) => rule.id), [
        'a',
        'b',
        'c',
      ]);
      expect(_storedIds(storage), ['a', 'b', 'c']);
    });

    test('reorder 越界下标被忽略', () {
      final storage = _MemoryLocalStorageService(
        initialValues: {
          StorageKeys.promptRegexRules: [_encodeRule(id: 'a', sortOrder: 0)],
        },
      );
      final container = _buildContainer(storage);

      container.read(promptRegexRulesProvider.notifier).reorder(3, 0);

      expect(container.read(promptRegexRulesProvider).map((rule) => rule.id), [
        'a',
      ]);
    });
  });
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService({Map<String, Object?> initialValues = const {}})
    : values = Map<String, Object?>.from(initialValues);

  final Map<String, Object?> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
