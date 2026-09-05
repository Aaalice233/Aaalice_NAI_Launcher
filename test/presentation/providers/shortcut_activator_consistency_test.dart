import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_key_mapping.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_manager.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';

class _DefaultShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

void main() {
  testWidgets('SingleActivator 与 LogicalKeySet 两条路径解析出同一主键', (tester) async {
    late BuildContext capturedContext;
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _DefaultShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedContext = context;
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final config = ShortcutConfig.createDefault();
    expect(config.bindings, isNotEmpty);

    for (final binding in config.bindings.values) {
      final shortcut = binding.effectiveShortcut!;
      final parsed = ShortcutParser.parse(shortcut)!;
      final expectedTrigger = parsed.key.logicalKeyboardKey;

      final activators = buildContextShortcuts(
        capturedContext,
        capturedRef,
        binding.context,
        {binding.id: () {}},
      );
      expect(activators, hasLength(1), reason: binding.id);

      final activator = activators.keys.single as SingleActivator;
      expect(activator.trigger, expectedTrigger, reason: binding.id);
      expect(
        activator.control,
        parsed.modifiers.contains(ShortcutModifier.control),
        reason: binding.id,
      );
      expect(
        activator.alt,
        parsed.modifiers.contains(ShortcutModifier.alt),
        reason: binding.id,
      );
      expect(
        activator.shift,
        parsed.modifiers.contains(ShortcutModifier.shift),
        reason: binding.id,
      );
      expect(
        activator.meta,
        parsed.modifiers.contains(ShortcutModifier.meta),
        reason: binding.id,
      );

      final keySet =
          AppShortcutManager.parseActivator(shortcut)! as LogicalKeySet;
      expect(keySet.keys, contains(expectedTrigger), reason: binding.id);
      expect(
        keySet.keys,
        hasLength(parsed.modifiers.length + 1),
        reason: binding.id,
      );
      expect(
        keySet.keys.difference({expectedTrigger}),
        parsed.modifiers.map((m) => m.logicalKeyboardKey).toSet(),
        reason: binding.id,
      );
    }
  });
}
