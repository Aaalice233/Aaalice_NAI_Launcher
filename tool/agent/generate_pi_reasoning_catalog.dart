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
const _reasoningCatalogPath =
    'lib/presentation/prompt_assistant/models/pi_reasoning_model_catalog.dart';
const _modelProfilesPath =
    'lib/presentation/prompt_assistant/models/pi_model_profiles.dart';

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
  final version = package['version'] as String;
  final outputs = <String, String>{
    _reasoningCatalogPath: _formatGeneratedCatalog(
      _generateReasoningCatalog(root, version),
    ),
    _modelProfilesPath: _formatGeneratedCatalog(
      _generateModelProfiles(root, version),
    ),
  };
  for (final entry in outputs.entries) {
    final target = File(entry.key);
    if (check) {
      if (!target.existsSync() || target.readAsStringSync() != entry.value) {
        stderr.writeln('${target.path} is not synchronized with ${root.path}.');
        exitCode = 1;
      } else {
        stdout.writeln('${target.path} is up to date.');
      }
      continue;
    }
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(entry.value, flush: true);
    stdout.writeln('Generated ${target.path} from pi-ai $version.');
  }
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

String _generateReasoningCatalog(Directory root, String version) {
  final output = StringBuffer()
    ..writeln('// GENERATED from @earendil-works/pi-ai $version.')
    ..writeln(
      '// Source: dist/providers/data/*.json and dist/models.js. Do not edit by hand.',
    )
    ..writeln()
    ..writeln("import '../../../core/agent/agent_types.dart';")
    ..writeln("import 'agent_protocol.dart';")
    ..writeln("import 'agent_reasoning_model_rule.dart';")
    ..writeln()
    ..writeln(
      'const piReasoningModelCatalog = '
      '<String, Map<String, AgentReasoningModelRule>>{',
    );

  for (final provider in _providers) {
    final models = [
      for (final model in _chatModels(root, provider))
        if (model['reasoning'] == true) model,
    ];

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
      final supportsEffort = _supportsReasoningEffort(model, compat);
      final thinkingBudgets = _thinkingBudgets(api, model['id'] as String);
      final disabledEffort = _disabledEffort(
        api,
        supportedLevels,
        sourceLevelMap,
      );
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

String _generateModelProfiles(Directory root, String version) {
  final output = StringBuffer()
    ..writeln('// GENERATED from @earendil-works/pi-ai $version.')
    ..writeln('// Source: dist/providers/data/*.json. Do not edit by hand.')
    ..writeln()
    ..writeln('typedef PiModelProfile = ({String? name, bool imageInput});')
    ..writeln()
    ..writeln('const piModelProfiles = <String, Map<String, PiModelProfile>>{');
  for (final provider in _providers) {
    output.writeln("  ${_quote(provider)}: {");
    for (final model in _chatModels(root, provider)) {
      final id = model['id'] as String;
      final name = (model['name'] as String?)?.trim() ?? '';
      final input = (model['input'] as List?)?.cast<String>() ?? const [];
      output.writeln(
        '    ${_quote(id)}: (name: ${name.isEmpty ? 'null' : _quote(name)}, '
        'imageInput: ${input.contains('image')}),',
      );
    }
    output.writeln('  },');
  }
  output.writeln('};');
  return output.toString();
}

// Pi 1.0 keys entries as "<type>:<id>" and ships image/classifier models in
// the same files; only chat models are selectable in the assistant.
List<Map<String, dynamic>> _chatModels(Directory root, String provider) {
  final data = _jsonObject(
    File('${root.path}/dist/providers/data/$provider.json'),
  );
  return <Map<String, dynamic>>[
    for (final apiModels in data.values)
      for (final model in (apiModels as Map<String, dynamic>).values)
        if (((model as Map<String, dynamic>)['type'] ?? 'chat') == 'chat')
          model,
  ]..sort(
    (left, right) => (left['id'] as String).compareTo(right['id'] as String),
  );
}

bool _supportsReasoningEffort(
  Map<String, dynamic> model,
  Map<String, dynamic> compat,
) {
  if (compat['supportsReasoningEffort'] case final bool value) return value;
  if (model['api'] != 'openai-completions') return false;
  // Pi resolves omitted compatibility fields from the endpoint, not from the
  // derived thinking format. Keep explicit provider overrides authoritative.
  final provider = model['provider'] as String;
  final url = model['baseUrl'] as String;
  return !(provider == 'xai' ||
      url.contains('api.x.ai') ||
      provider == 'zai' ||
      provider == 'zai-coding-cn' ||
      url.contains('api.z.ai') ||
      url.contains('open.bigmodel.cn') ||
      provider == 'moonshotai' ||
      provider == 'moonshotai-cn' ||
      url.contains('api.moonshot.') ||
      provider == 'together' ||
      url.contains('api.together.ai') ||
      url.contains('api.together.xyz') ||
      provider == 'cloudflare-ai-gateway' ||
      url.contains('gateway.ai.cloudflare.com') ||
      provider == 'nvidia' ||
      url.contains('integrate.api.nvidia.com') ||
      provider == 'ant-ling' ||
      url.contains('api.ant-ling.com'));
}

bool _supportsLevel(
  String api,
  String modelId,
  String level,
  Map<String, dynamic> levelMap,
) {
  // Google's documented 2.5 Pro budget starts at 128; zero is not supported.
  if (api == 'geminiBudget' && modelId.contains('2.5-pro') && level == 'off') {
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
        level: _googleThinkingLevel(source, level),
  };
}

String _googleThinkingLevel(Map<String, dynamic> levelMap, String level) =>
    ((levelMap[level] as String?) ?? level).toUpperCase();

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

// Thinking-level Gemini models cannot fully disable thinking; Pi clamps "off"
// to the lowest supported level and sends that instead.
String? _disabledEffort(
  String api,
  List<String> supportedLevels,
  Map<String, dynamic> levelMap,
) {
  if (api != 'geminiLevel') return null;
  final fallback = supportedLevels.firstOrNull ?? 'off';
  if (fallback == 'off') return null;
  return _googleThinkingLevel(levelMap, fallback);
}

bool _usesGoogleThinkingLevel(String modelId) {
  final id = modelId.toLowerCase();
  return RegExp(r'gemini-3(?:\.\d+)?-(?:pro|flash)').hasMatch(id) ||
      id == 'gemini-flash-latest' ||
      id == 'gemini-flash-lite-latest' ||
      RegExp(r'gemma-?4').hasMatch(id);
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
    return _usesGoogleThinkingLevel(id) ? 'geminiLevel' : 'geminiBudget';
  }
  if (api == 'mistral-conversations') {
    return model['thinkingLevelMap'] == null
        ? 'mistralPromptMode'
        : 'mistralEffort';
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
