import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_model_capability.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/pi_reasoning_model_catalog.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/reasoning_payload.dart';

ProviderProtocol protocolFor(AgentReasoningApi api) => switch (api) {
  AgentReasoningApi.openAiResponses => ProviderProtocol.openaiResponses,
  AgentReasoningApi.anthropicAdaptive ||
  AgentReasoningApi.anthropicBudget => ProviderProtocol.anthropicMessages,
  AgentReasoningApi.geminiBudget ||
  AgentReasoningApi.geminiLevel => ProviderProtocol.geminiGenerateContent,
  _ => ProviderProtocol.openaiChatCompletions,
};

void main() {
  for (final provider in piReasoningModelCatalog.entries) {
    test(
      '${provider.key}: every selectable catalog level reaches a native control',
      () {
        for (final model in provider.value.entries) {
          final metadata = AssistantModelCatalog.resolveProvider(
            provider: ProviderConfig(
              id: provider.key,
              name: provider.key,
              baseUrl: 'https://example.invalid',
              protocol: protocolFor(model.value.api),
            ),
            model: model.key,
          );
          expect(metadata.reasoning, isTrue, reason: model.key);
          final controls = <Object>{};
          for (final level in metadata.selectableThinkingLevels) {
            final request = metadata.resolveReasoningRequest(
              level == ThinkingLevel.off ? null : level.name,
            )!;
            final reason = '${provider.key}/${model.key}/${level.name}';
            final control = (
              request.enabled,
              request.effort,
              request.budgetTokens,
            );
            expect(
              controls.add(control),
              isTrue,
              reason: '$reason repeats a visible control',
            );
            expect(request.enabled, level != ThinkingLevel.off, reason: reason);
            switch (request.api) {
              case AgentReasoningApi.deepSeek:
              case AgentReasoningApi.qwen:
                final payload = chatReasoningPayload(request);
                expect(payload, isNotEmpty, reason: reason);
                if (request.enabled && model.value.supportsReasoningEffort) {
                  expect(
                    payload['reasoning_effort'],
                    model.value.mappedLevel(level),
                    reason: reason,
                  );
                } else {
                  expect(
                    payload.containsKey('reasoning_effort'),
                    isFalse,
                    reason: reason,
                  );
                }
              case AgentReasoningApi.openAiCompletions:
              case AgentReasoningApi.mistralEffort:
                final payload = chatReasoningPayload(request);
                if (request.enabled) {
                  expect(
                    payload['reasoning_effort'],
                    isNotEmpty,
                    reason: reason,
                  );
                }
              case AgentReasoningApi.openRouter:
                final payload = chatReasoningPayload(request);
                if (request.enabled) {
                  expect(
                    (payload['reasoning'] as Map)['effort'],
                    isNotEmpty,
                    reason: reason,
                  );
                }
              case AgentReasoningApi.mistralPromptMode:
                expect(
                  chatReasoningPayload(request),
                  request.enabled ? {'prompt_mode': 'reasoning'} : {},
                  reason: reason,
                );
              case AgentReasoningApi.openAiResponses:
                if (request.enabled) {
                  expect(
                    responsesReasoningEffort(request, null),
                    isNotEmpty,
                    reason: reason,
                  );
                }
              case AgentReasoningApi.anthropicAdaptive:
              case AgentReasoningApi.anthropicBudget:
                final payload = anthropicReasoningPayload(
                  reasoning: request,
                  modelMaxOutputTokens: metadata.maxOutputTokens,
                );
                if (request.enabled) {
                  expect(payload, contains('thinking'), reason: reason);
                  if (request.api == AgentReasoningApi.anthropicBudget) {
                    final budget =
                        (payload['thinking'] as Map)['budget_tokens'] as int;
                    expect(budget, greaterThanOrEqualTo(1024), reason: reason);
                    expect(
                      payload['max_tokens'] as int,
                      greaterThan(budget),
                      reason: reason,
                    );
                  } else {
                    expect(
                      (payload['output_config'] as Map)['effort'],
                      isNotEmpty,
                      reason: reason,
                    );
                  }
                }
              case AgentReasoningApi.geminiBudget:
                final payload = geminiThinkingConfig(request)!;
                expect(payload['thinkingBudget'], isA<int>(), reason: reason);
                if (request.enabled) {
                  expect(payload['thinkingBudget'], isNot(0), reason: reason);
                }
              case AgentReasoningApi.geminiLevel:
                final payload = geminiThinkingConfig(request);
                if (request.enabled) {
                  expect(payload?['thinkingLevel'], isNotEmpty, reason: reason);
                }
            }
          }
        }
      },
    );
  }

  test(
    'Gemini Pro cannot disable thinking, latest aliases use level controls',
    () {
      final provider = ProviderPreset.gemini.createConfig();
      final pro = AssistantModelCatalog.resolveProvider(
        provider: provider,
        model: 'gemini-2.5-pro',
      );
      expect(pro.selectableThinkingLevels, isNot(contains(ThinkingLevel.off)));
      expect(geminiThinkingConfig(pro.resolveReasoningRequest(null)), isNull);
      for (final alias in ['gemini-flash-latest', 'gemini-flash-lite-latest']) {
        final metadata = AssistantModelCatalog.resolveProvider(
          provider: provider,
          model: alias,
        );
        expect(metadata.reasoningRule?.api, AgentReasoningApi.geminiLevel);
        expect(
          geminiThinkingConfig(metadata.resolveReasoningRequest('high')),
          containsPair('thinkingLevel', 'HIGH'),
        );
      }
    },
  );
}
