import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/mcp/services/mcp_external_tool_registry_factory.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late ProviderContainer container;
  late McpExternalToolRegistryFactory factory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mcp_tool_surface_');
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
          ),
        ),
      ],
    );
    factory = McpExternalToolRegistryFactory(
      ref: container.read(_refProvider),
      supportDir: root,
      workspaceDir: root.path,
      isHostAlive: () => true,
    );
  });

  tearDown(() async {
    container.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('external surface exposes unique strict tool contracts', () {
    final registry = factory.build(AgentPermissionMode.askBeforeSensitiveActions);
    final names = registry.tools.map((tool) => tool.name).toList();

    expect(names, isNotEmpty);
    expect(names.toSet(), hasLength(names.length));
    for (final tool in registry.tools) {
      expect(tool.parameters['type'], 'object', reason: tool.name);
      expect(
        tool.parameters['additionalProperties'],
        isFalse,
        reason: tool.name,
      );
      expect(
        () => describeAgentToolPermission(tool.name),
        returnsNormally,
        reason: tool.name,
      );
      expect(
        () => registry.catalog.descriptorFor(tool.name),
        returnsNormally,
        reason: tool.name,
      );
    }
  });

  test('chat-only tools never reach external clients', () {
    for (final mode in AgentPermissionMode.values) {
      final names = factory.build(mode).tools.map((tool) => tool.name).toSet();
      for (final excluded in McpExternalToolSurface.excludedToolNames) {
        expect(names, isNot(contains(excluded)), reason: '$mode/$excluded');
      }
    }
  });

  test('repeated builds keep tool order stable', () {
    final first = factory
        .build(AgentPermissionMode.askBeforeSensitiveActions)
        .tools
        .map((tool) => tool.name)
        .toList();
    final second = factory
        .build(AgentPermissionMode.askBeforeSensitiveActions)
        .tools
        .map((tool) => tool.name)
        .toList();

    expect(second, first);
  });

  test('safe mode exposes read operations only', () {
    final registry = factory.build(AgentPermissionMode.safe);

    expect(registry.tools, isNotEmpty);
    for (final tool in registry.tools) {
      expect(
        registry.catalog.descriptorFor(tool.name).operation,
        AgentPermissionOperation.read,
        reason: tool.name,
      );
    }
  });

  test('full access exposes write operations', () {
    final registry = factory.build(AgentPermissionMode.fullAccess);
    final operations = registry.tools
        .map((tool) => registry.catalog.descriptorFor(tool.name).operation)
        .toSet();

    expect(operations, contains(AgentPermissionOperation.read));
    expect(
      operations.any(
        (operation) => operation != AgentPermissionOperation.read,
      ),
      isTrue,
    );
  });
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }
}
