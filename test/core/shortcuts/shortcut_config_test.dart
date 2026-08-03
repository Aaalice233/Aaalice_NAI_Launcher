import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';

void main() {
  test(
    'new generation navigation defaults use arrows in generation context',
    () {
      final config = ShortcutConfig.createDefault();

      expect(
        config.getEffectiveShortcut(ShortcutIds.generationPrevImage),
        'arrowleft',
      );
      expect(
        config.getEffectiveShortcut(ShortcutIds.generationNextImage),
        'arrowright',
      );
      expect(
        config.getBinding(ShortcutIds.generationPrevImage)?.context,
        ShortcutContext.generation,
      );
    },
  );

  test('mergedWithDefaults only adds missing ids', () {
    const customized = ShortcutBinding(
      id: ShortcutIds.generateImage,
      actionKey: 'shortcut_action_generate_image',
      defaultShortcut: 'ctrl+enter',
      customShortcut: 'alt+g',
      context: ShortcutContext.generation,
      enabled: false,
    );
    final stored = ShortcutConfig(
      bindings: {customized.id: customized},
      enableShortcuts: false,
    );

    final merged = stored.mergedWithDefaults();

    expect(merged.bindings[customized.id], customized);
    expect(merged.bindings, contains(ShortcutIds.generationPrevImage));
    expect(merged.enableShortcuts, isFalse);
  });

  test('conflicts are isolated by context except for global bindings', () {
    const config = ShortcutConfig(
      bindings: {
        'viewer-left': ShortcutBinding(
          id: 'viewer-left',
          actionKey: 'viewer-left',
          defaultShortcut: 'arrowleft',
          context: ShortcutContext.viewer,
        ),
        'generation-left': ShortcutBinding(
          id: 'generation-left',
          actionKey: 'generation-left',
          defaultShortcut: 'arrowleft',
          context: ShortcutContext.generation,
        ),
        'global-left': ShortcutBinding(
          id: 'global-left',
          actionKey: 'global-left',
          defaultShortcut: 'arrowleft',
          context: ShortcutContext.global,
        ),
      },
    );

    expect(
      config.findConflicts(
        'arrowleft',
        context: ShortcutContext.generation,
        excludeId: 'generation-left',
      ),
      ['global-left'],
    );
    expect(
      config.findConflicts(
        'arrowleft',
        context: ShortcutContext.global,
        excludeId: 'global-left',
      ),
      unorderedEquals(['viewer-left', 'generation-left']),
    );
  });
}
