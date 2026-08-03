import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_storage.dart';

void main() {
  const customized = ShortcutBinding(
    id: ShortcutIds.generateImage,
    actionKey: 'shortcut_action_generate_image',
    defaultShortcut: 'ctrl+enter',
    customShortcut: 'alt+g',
    context: ShortcutContext.generation,
    enabled: false,
  );

  ShortcutConfig legacyConfig() => const ShortcutConfig(
    bindings: {ShortcutIds.generateImage: customized},
    enableShortcuts: false,
  );

  test(
    'load merges missing defaults and persists without replacing custom data',
    () async {
      String? persisted;
      final storage = ShortcutStorage.forTesting(
        readConfig: () async => jsonEncode(legacyConfig().toJson()),
        writeConfig: (value) async => persisted = value,
      );

      final loaded = await storage.loadConfig();

      expect(loaded.bindings[ShortcutIds.generateImage], customized);
      expect(loaded.enableShortcuts, isFalse);
      expect(loaded.bindings, contains(ShortcutIds.generationPrevImage));
      expect(persisted, isNotNull);
      expect(
        ShortcutConfig.fromJson(jsonDecode(persisted!) as Map<String, dynamic>),
        loaded,
      );
    },
  );

  test('load returns merged config when persisting the merge fails', () async {
    final storage = ShortcutStorage.forTesting(
      readConfig: () async => jsonEncode(legacyConfig().toJson()),
      writeConfig: (_) async => throw const FileSystemException('read only'),
    );

    final loaded = await storage.loadConfig();

    expect(loaded.bindings[ShortcutIds.generateImage], customized);
    expect(loaded.bindings, contains(ShortcutIds.generationNextImage));
    expect(loaded.enableShortcuts, isFalse);
  });

  test(
    'import merges defaults before persisting and returning config',
    () async {
      String? persisted;
      final storage = ShortcutStorage.forTesting(
        readConfig: () async => null,
        writeConfig: (value) async => persisted = value,
      );

      final imported = await storage.importConfig(
        jsonEncode(legacyConfig().toJson()),
      );

      expect(imported.bindings[ShortcutIds.generateImage], customized);
      expect(imported.bindings, contains(ShortcutIds.generationPrevImage));
      expect(
        ShortcutConfig.fromJson(jsonDecode(persisted!) as Map<String, dynamic>),
        imported,
      );
    },
  );
}
