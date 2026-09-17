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
    final registry = factory.build(
      AgentPermissionMode.askBeforeSensitiveActions,
    );
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

  test('external tool schemas never declare a default keyword', () {
    for (final mode in AgentPermissionMode.values) {
      for (final tool in factory.build(mode).tools) {
        expect(
          _defaultKeywordPaths(tool.parameters, tool.name),
          isEmpty,
          reason:
              '$mode/${tool.name}: external MCP clients materialize schema '
              'default into arguments while validate_tool_arguments never '
              'does, so an omitted field arrives populated',
        );
      }
    }
  });

  test('default keyword sweep separates keywords from property names', () {
    expect(
      _defaultKeywordPaths({
        'type': 'object',
        'properties': {
          'mode': {'type': 'string', 'default': 'ai_choice'},
          'nested': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'deep': {'type': 'integer', 'default': 1},
              },
            },
          },
        },
      }, 'probe'),
      [
        'probe/properties/mode',
        'probe/properties/nested/items/properties/deep',
      ],
    );
    expect(
      _defaultKeywordPaths({
        'type': 'object',
        'properties': {
          'default': {'type': 'string'},
        },
        'required': ['default'],
      }, 'probe'),
      isEmpty,
    );
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

  test('external image tools use full-resolution path-free contracts', () {
    final tools = factory.build(AgentPermissionMode.fullAccess).tools;
    expect(tools.map((tool) => tool.name), contains('display_images'));
    for (final name in [
      'generate_image',
      'submit_generation',
      'display_images',
      'inspect_images',
    ]) {
      final tool = tools.singleWhere((tool) => tool.name == name);
      expect(tool.description, contains('full-resolution MCP ImageContent'));
      expect(tool.description, contains('top-level display_markdown'));
      expect(tool.description, contains('final answer'));
      expect(tool.description, contains('ImageContent alone is not'));
      expect(tool.description, isNot(contains('workspace-relative')));
      expect(tool.description, isNot(contains('NOT shown to the user')));
    }
    for (final name in [
      'generate_image',
      'submit_generation',
      'display_images',
    ]) {
      expect(
        tools.singleWhere((tool) => tool.name == name).description,
        contains('its own turn'),
      );
    }
    expect(
      tools.singleWhere((tool) => tool.name == 'inspect_images').description,
      isNot(contains('its own turn')),
    );
    final recent = tools.singleWhere(
      (tool) => tool.name == 'get_recent_images',
    );
    expect(recent.description, contains('not image bytes or local paths'));
    final display = tools.singleWhere((tool) => tool.name == 'display_images');
    expect(
      display.parameters['properties']['include_display_file']['type'],
      'boolean',
    );
    expect(display.description, contains('display_markdown'));
    expect(
      display.parameters['properties']['include_display_url']['type'],
      'boolean',
    );
    expect(display.description, contains('Cherry Studio'));
    expect(display.description, contains('HTTP reference'));
    for (final name in [
      'generate_image',
      'submit_generation',
      'display_images',
      'inspect_images',
    ]) {
      expect(
        tools.singleWhere((tool) => tool.name == name).description.length,
        lessThan(1200),
      );
    }
    final generate = tools.singleWhere((tool) => tool.name == 'generate_image');
    expect(generate.description, contains('ONLY prepares'));
    expect(generate.parameters['required'], isNot(contains('prompt')));
    for (final name in [
      'prepare_generation',
      'update_generation_preparation',
      'generate_image',
      'queue_image_task',
    ]) {
      final tool = tools.singleWhere((tool) => tool.name == name);
      expect(
        tool.parameters['properties']['include_parameters']['type'],
        'boolean',
      );
    }
    final context = tools.singleWhere(
      (tool) => tool.name == 'get_application_context',
    );
    expect(
      context.parameters['properties']['include_draft_details']['type'],
      'boolean',
    );
    final submit = tools.singleWhere(
      (tool) => tool.name == 'submit_generation',
    );
    expect(
      submit.parameters['properties']['include_display_file']['type'],
      'boolean',
    );
    expect(submit.description, contains('no status/history/display call'));
  });

  test('create_inpaint_mask sends MCP clients to inspect_images', () {
    final tool = factory
        .build(AgentPermissionMode.fullAccess)
        .tools
        .singleWhere((tool) => tool.name == 'create_inpaint_mask');

    expect(tool.description, contains('inspect_images'));
    expect(tool.description, contains('resource_ref'));
    expect(tool.description, contains('full resolution'));
    expect(tool.description, isNot(contains('read tool')));
    expect(
      tool.parameters['properties']['regions']['maxItems'],
      16,
      reason: 'the description override must keep the authored mask schema',
    );
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
      operations.any((operation) => operation != AgentPermissionOperation.read),
      isTrue,
    );
  });
}

// Keys under properties/$defs are parameter names, not keywords, so a parameter
// literally named default must not be reported.
List<String> _defaultKeywordPaths(Object? node, String path) {
  const nameKeyedGroups = {'properties', r'$defs', 'definitions'};
  final hits = <String>[];
  if (node is Map) {
    if (node.containsKey('default')) hits.add(path);
    for (final entry in node.entries) {
      final key = entry.key.toString();
      final childPath = '$path/$key';
      final value = entry.value;
      if (nameKeyedGroups.contains(key) && value is Map) {
        for (final named in value.entries) {
          hits.addAll(
            _defaultKeywordPaths(named.value, '$childPath/${named.key}'),
          );
        }
        continue;
      }
      hits.addAll(_defaultKeywordPaths(value, childPath));
    }
  } else if (node is List) {
    for (var index = 0; index < node.length; index++) {
      hits.addAll(_defaultKeywordPaths(node[index], '$path/$index'));
    }
  }
  return hits;
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
