import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_toolbox.dart';

final _refProvider = Provider<Ref>((ref) => ref);

Ref _makeRef(ProviderContainer container) => container.read(_refProvider);

void main() {
  test('registers image generation tools', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tools = GenerationToolbox(_makeRef(container)).tools();
    expect(
      tools.map((t) => t.name),
      containsAll([
        'interrogate_image',
        'generate_image',
        'queue_image_task',
        'get_generation_status',
      ]),
    );
  });

  test('queue_image_task rejects empty prompt', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(_makeRef(container))
        .tools()
        .firstWhere((t) => t.name == 'queue_image_task');
    final result = await tool.execute('t2', {});
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('prompt'));
  });

  test('generate_image rejects empty prompt without touching providers',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(_makeRef(container))
        .tools()
        .firstWhere((t) => t.name == 'generate_image');
    final result = await tool.execute('t1', {});
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('prompt'));
  });

  test('get_generation_status reports generation and queue sections',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(_makeRef(container))
        .tools()
        .firstWhere((t) => t.name == 'get_generation_status');
    final result = await tool.execute('t3', {});
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('"generation"'));
    expect(text, contains('"queue"'));
  });

  test('interrogate_image reports missing file', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = GenerationToolbox(_makeRef(container))
        .tools()
        .firstWhere((t) => t.name == 'interrogate_image');
    final result = await tool.execute('t4', {'path': 'Z:/no_such.png'});
    final text = result.content
        .whereType<ToolResultTextContent>()
        .map((c) => c.text)
        .join();
    expect(text, contains('not found'));
  });
}
