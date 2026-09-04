import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _providers = <String>[
  'openai',
  'anthropic',
  'google',
  'deepseek',
  'openrouter',
  'xai',
  'mistral',
  'groq',
  'cerebras',
  'minimax',
  'minimax-cn',
  'kimi-coding',
  'moonshotai',
  'moonshotai-cn',
  'qwen-token-plan',
  'qwen-token-plan-cn',
  'qwen-token-plan-individual',
];
const _levels = <String>[
  'off',
  'minimal',
  'low',
  'medium',
  'high',
  'xhigh',
  'max',
];
const _mistralEffortModels = <String>{
  'mistral-small-2603',
  'mistral-small-latest',
  'mistral-medium-3.5',
};

void main(List<String> arguments) {
  final check = arguments.contains('--check');
  final rootArgument = _option(arguments, '--pi-ai-root');
  final appData = Platform.environment['APPDATA'];
  final defaultRoot = appData == null
      ? null
      : '$appData/npm/node_modules/@earendil-works/pi-coding-agent/'
            'node_modules/@earendil-works/pi-ai';
  final root = Directory(rootArgument ?? defaultRoot ?? '');
  if (!root.existsSync()) {
    stderr.writeln(
      'pi-ai not found. Pass --pi-ai-root <path> to the installed package.',
    );
    exitCode = 2;
    return;
  }

  final package = _jsonObject(File('${root.path}/package.json'));
  final sourceLock = _jsonObject(
    File('tool/agent/pi_reasoning_source_lock.json'),
  );
  _validateSourceLock(root, package, sourceLock);
  final output = _formatGeneratedCatalog(
    _generate(root, package['version'] as String),
  );
  final target = File(
    'lib/presentation/agent_chat/model/pi_reasoning_model_catalog.dart',
  );
  if (check) {
    if (!target.existsSync() || target.readAsStringSync() != output) {
      stderr.writeln('${target.path} is not synchronized with ${root.path}.');
      exitCode = 1;
    } else {
      stdout.writeln('${target.path} is up to date.');
    }
    return;
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(output, flush: true);
  stdout.writeln('Generated ${target.path} from pi-ai ${package['version']}.');
}

void _validateSourceLock(
  Directory root,
  Map<String, dynamic> package,
  Map<String, dynamic> sourceLock,
) {
  final expectedVersion = sourceLock['version'] as String;
  final actualVersion = package['version'] as String?;
  if (actualVersion != expectedVersion) {
    throw StateError(
      'Expected pi-ai $expectedVersion but found ${actualVersion ?? 'unknown'}.',
    );
  }
  final files = (sourceLock['files'] as Map<String, dynamic>)
      .cast<String, String>();
  for (final entry in files.entries) {
    final file = File('${root.path}/${entry.key}');
    if (!file.existsSync()) {
      throw StateError('Locked pi-ai source is missing: ${entry.key}');
    }
    final actualHash = sha256.convert(file.readAsBytesSync()).toString();
    if (actualHash != entry.value) {
      throw StateError(
        'Locked pi-ai source changed: ${entry.key} ($actualHash).',
      );
    }
  }
}

String _formatGeneratedCatalog(String source) {
  final temp = File('tool/.tmp/pi_reasoning_model_catalog.dart');
  temp.parent.createSync(recursive: true);
  try {
    temp.writeAsStringSync(source, flush: true);
    final result = Process.runSync(Platform.resolvedExecutable, [
      'format',
      temp.path,
    ]);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      throw StateError('Failed to format the generated reasoning catalog.');
    }
    return temp.readAsStringSync();
  } finally {
    if (temp.existsSync()) temp.deleteSync();
  }
}

String _generate(Directory root, String version) {
  final output = StringBuffer()
    ..writeln('// GENERATED from @earendil-works/pi-ai $version.')
    ..writeln(
      '// Source: dist/providers/data/*.json and dist/models.js. Do not edit by hand.',
    )
    ..writeln()
    ..writeln("import '../../../core/agent/agent_types.dart';")
    ..writeln("import '../../prompt_assistant/models/agent_protocol.dart';")
    ..writeln("import 'agent_reasoning_model_rule.dart';")
    ..writeln()
    ..writeln(
      'const piReasoningModelCatalog = '
      '<String, Map<String, AgentReasoningModelRule>>{',
    );

  for (final provider in _providers) {
    final data = _jsonObject(
      File('${root.path}/dist/providers/data/$provider.json'),
    );
    final models =
        <Map<String, dynamic>>[
          for (final apiModels in data.values)
            for (final model in (apiModels as Map<String, dynamic>).values)
              if ((model as Map<String, dynamic>)['reasoning'] == true) model,
        ]..sort(
          (left, right) =>
              (left['id'] as String).compareTo(right['id'] as String),
        );

    output.writeln("  ${_quote(provider)}: {");
    for (final model in models) {
      final modelId = model['id'] as String;
      final sourceLevelMap =
          (model['thinkingLevelMap'] as Map<String, dynamic>?) ?? {};
      final compat = (model['compat'] as Map<String, dynamic>?) ?? {};
      final api = _reasoningApi(model, compat);
      final supportedLevels = <String>[
        for (final level in _levels)
          if (_supportsLevel(api, modelId, level, sourceLevelMap)) level,
      ];
      final emittedLevelMap = _emittedLevelMap(api, modelId, sourceLevelMap);
      final mapEntries = <String>[
        for (final level in _levels)
          if (emittedLevelMap.containsKey(level))
            'ThinkingLevel.$level: '
                '${emittedLevelMap[level] == null ? 'null' : _quote(emittedLevelMap[level] as String)}',
      ];
      final supportsEffort =
          compat['supportsReasoningEffort'] as bool? ??
          api == 'openAiCompletions';
      final thinkingBudgets = _thinkingBudgets(api, model['id'] as String);
      final disabledEffort = _disabledEffort(api, model['id'] as String);
      output.writeln(
        '    ${_quote(model['id'] as String)}: AgentReasoningModelRule('
        'api: AgentReasoningApi.$api, '
        'levels: [${supportedLevels.map((level) => 'ThinkingLevel.$level').join(', ')}], '
        'levelMap: {${mapEntries.join(', ')}}, '
        'supportsReasoningEffort: $supportsEffort, '
        'requiresReasoningContent: '
        "${compat['requiresReasoningContentOnAssistantMessages'] == true}, "
        "allowEmptySignature: ${compat['allowEmptySignature'] == true}, "
        "alwaysIncludeEncryptedReasoning: ${provider == 'xai'}, "
        'thinkingBudgets: {${thinkingBudgets.entries.map((entry) => 'ThinkingLevel.${entry.key}: ${entry.value}').join(', ')}}, '
        "disabledEffort: ${disabledEffort == null ? 'null' : _quote(disabledEffort)}, "
        "contextWindow: ${model['contextWindow']}, "
        "maxOutputTokens: ${model['maxTokens']}),",
      );
    }
    output.writeln('  },');
  }
  output.writeln('};');
  return output.toString();
}

bool _supportsLevel(
  String api,
  String modelId,
  String level,
  Map<String, dynamic> levelMap,
) {
  if (api == 'geminiLevel' &&
      level == 'minimal' &&
      _geminiMinimumLevel(modelId) == 'LOW') {
    return false;
  }
  if (levelMap[level] == null && levelMap.containsKey(level)) return false;
  if ((level == 'xhigh' || level == 'max') && !levelMap.containsKey(level)) {
    return false;
  }
  return true;
}

Map<String, dynamic> _emittedLevelMap(
  String api,
  String modelId,
  Map<String, dynamic> source,
) {
  if (api != 'geminiLevel') return source;
  return {
    for (final level in _levels)
      if (source[level] == null && source.containsKey(level))
        level: null
      else if (level != 'off' && _supportsLevel(api, modelId, level, source))
        level: _geminiNativeLevel(
          modelId,
          (source[level] as String?)?.toLowerCase() ?? level,
        ),
  };
}

String _geminiNativeLevel(String modelId, String level) {
  final id = modelId.toLowerCase();
  if (RegExp(r'gemini-3(?:\.\d+)?-pro').hasMatch(id)) {
    return level == 'minimal' || level == 'low' ? 'LOW' : 'HIGH';
  }
  if (RegExp(r'gemma-?4').hasMatch(id)) {
    return level == 'minimal' || level == 'low' ? 'MINIMAL' : 'HIGH';
  }
  return level.toUpperCase();
}

Map<String, int> _thinkingBudgets(String api, String modelId) {
  if (api != 'geminiBudget') return const {};
  if (modelId.contains('2.5-pro')) {
    return const {'minimal': 128, 'low': 2048, 'medium': 8192, 'high': 32768};
  }
  if (modelId.contains('2.5-flash-lite')) {
    return const {'minimal': 512, 'low': 2048, 'medium': 8192, 'high': 24576};
  }
  if (modelId.contains('2.5-flash')) {
    return const {'minimal': 128, 'low': 2048, 'medium': 8192, 'high': 24576};
  }
  return const {};
}

String? _disabledEffort(String api, String modelId) {
  if (api != 'geminiLevel') return null;
  return _geminiMinimumLevel(modelId);
}

String _geminiMinimumLevel(String modelId) {
  final normalizedId = modelId.toLowerCase();
  if (RegExp(r'gemini-3(?:\.\d+)?-pro').hasMatch(normalizedId) ||
      normalizedId == 'gemini-3.7-flash' ||
      normalizedId == 'gemini-3.8-flash') {
    return 'LOW';
  }
  return 'MINIMAL';
}

String _reasoningApi(Map<String, dynamic> model, Map<String, dynamic> compat) {
  final api = model['api'];
  final id = model['id'] as String;
  if (api == 'openai-responses') return 'openAiResponses';
  if (api == 'anthropic-messages') {
    return compat['forceAdaptiveThinking'] == true
        ? 'anthropicAdaptive'
        : 'anthropicBudget';
  }
  if (api == 'google-generative-ai') {
    return id.startsWith('gemini-3') || id.startsWith('gemma-4')
        ? 'geminiLevel'
        : 'geminiBudget';
  }
  if (api == 'mistral-conversations') {
    return _mistralEffortModels.contains(id)
        ? 'mistralEffort'
        : 'mistralPromptMode';
  }
  return switch (compat['thinkingFormat']) {
    'deepseek' => 'deepSeek',
    'openrouter' => 'openRouter',
    'qwen' => 'qwen',
    _ => 'openAiCompletions',
  };
}

Map<String, dynamic> _jsonObject(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1) return null;
  if (index + 1 >= arguments.length) {
    stderr.writeln('$name requires a value.');
    exit(2);
  }
  return arguments[index + 1];
}

String _quote(String value) => "'${value.replaceAll("'", r"\'")}'";
