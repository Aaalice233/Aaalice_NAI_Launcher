import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation code does not derive input modality from the OS', () {
    final violations = <String>[];

    for (final file in _dartFilesUnder('lib/presentation')) {
      if (file.path.endsWith(
        'adaptive${Platform.pathSeparator}'
        'interaction_policy.dart',
      )) {
        continue;
      }
      final source = file.readAsStringSync();
      if (_readsOsInputModality(source) ||
          (_readsPlatformIdentity(source) &&
              !_mayReadPlatformIdentity(file.path))) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'UI input modality must come from InteractionPolicyScope, not the '
          'operating system:\n${violations.join('\n')}',
    );
  });

  test('platform capabilities do not expose OS-derived input getters', () {
    final source = File(
      'lib/core/platform/platform_capabilities.dart',
    ).readAsStringSync();

    expect(_declaresOsInputGetter(source), isFalse);
  });

  test('input-modality contract detects PlatformCapabilities aliases', () {
    const source = '''
final capabilities = PlatformCapabilities.current;
final showHoverTools = capabilities.hasPrecisePointer;
''';

    expect(_readsOsInputModality(source), isTrue);
  });

  test('input-modality contract detects platform-derived UI policy', () {
    expect(
      _readsPlatformIdentity(
        'final hover = defaultTargetPlatform == TargetPlatform.windows;',
      ),
      isTrue,
    );
    expect(_readsPlatformIdentity('final rich = theme.platform;'), isTrue);
  });

  test('input-modality contract detects TargetPlatform input inference', () {
    const legacyWeightToolbarPolicy = '''
bool supportsPromptWeightScrollPhysics(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.windows || TargetPlatform.macOS => true,
    _ => false,
  };
}
''';
    const namedNullableParameter = '''
bool supportsHover({required TargetPlatform? targetPlatform}) =>
    targetPlatform == TargetPlatform.windows;
''';

    expect(_readsPlatformIdentity(legacyWeightToolbarPolicy), isTrue);
    expect(_readsPlatformIdentity(namedNullableParameter), isTrue);
  });
}

bool _readsPlatformIdentity(String source) =>
    source.contains('defaultTargetPlatform') ||
    RegExp(r'\btheme\s*\.\s*platform\b').hasMatch(source) ||
    RegExp(
      r'\bTargetPlatform\s*\??\s+[A-Za-z_]\w*\s*(?=[,)=;}])',
    ).hasMatch(source);

bool _mayReadPlatformIdentity(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith(
        'presentation/widgets/common/themed_text_selection_toolbar.dart',
      ) ||
      normalized.endsWith(
        'presentation/agent_chat/services/application_context_toolbox.dart',
      );
}

bool _declaresOsInputGetter(String source) => RegExp(
  r'\bbool\s+get\s+(hasTouchInput|hasPrecisePointer)\b',
).hasMatch(source);

bool _readsOsInputModality(String source) {
  const inputFields = r'(hasTouchInput|hasPrecisePointer)';
  final directRead = RegExp(
    r'PlatformCapabilities\s*\.\s*current\s*\.\s*' + inputFields,
  );
  if (directRead.hasMatch(source)) return true;

  final aliasDeclaration = RegExp(
    r'\b([A-Za-z_]\w*)\s*=\s*PlatformCapabilities\s*\.\s*current\b',
  );
  for (final match in aliasDeclaration.allMatches(source)) {
    final alias = match.group(1)!;
    final aliasRead = RegExp(
      r'\b' + RegExp.escape(alias) + r'\s*\.\s*' + inputFields,
    );
    if (aliasRead.hasMatch(source)) return true;
  }
  return false;
}

Iterable<File> _dartFilesUnder(String path) sync* {
  for (final entity in Directory(path).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}
