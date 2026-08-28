import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../providers/generation/generation_params_notifier.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'precise_reference_toolbox.dart';
import 'toolbox_json.dart';
import 'vibe_library_toolbox.dart';

class ReferenceLibraryToolbox {
  ReferenceLibraryToolbox(this._ref, this._resolver);

  final Ref _ref;
  final AgentResourceResolver _resolver;

  List<AgentTool> tools() => [
    ...VibeLibraryToolbox(_ref, _resolver).tools(),
    ...PreciseReferenceToolbox(_ref, _resolver).tools(),
    _listActiveReferences(),
  ];

  DefinedAgentTool _listActiveReferences() => DefinedAgentTool(
    name: 'get_active_generation_references',
    label: 'Get Active Generation References',
    description: 'Read current Vibe and Precise Reference parameters.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      final params = _ref.read(generationParamsNotifierProvider);
      return agentToolJsonResult({
        'ok': true,
        'vibes': [
          for (final indexed in params.vibeReferencesV4.indexed)
            {
              'index': indexed.$1,
              'name': indexed.$2.displayName,
              'strength': indexed.$2.strength,
              'information_extracted': indexed.$2.infoExtracted,
              'enabled': indexed.$2.enabled,
            },
        ],
        'precise_references': [
          for (final indexed in params.preciseReferences.indexed)
            {
              'index': indexed.$1,
              'type': indexed.$2.type.name,
              'strength': indexed.$2.strength,
              'fidelity': indexed.$2.fidelity,
              'enabled': indexed.$2.enabled,
            },
        ],
      });
    },
  );
}
