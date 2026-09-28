import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';

void main() {
  test('production toolbox names receive semantic permission metadata', () {
    expect(
      describeAgentToolPermission('queue_image_task').domain,
      AgentPermissionDomain.generationQueue,
    );
    expect(
      describeAgentToolPermission('list_online_gallery_sources').operation,
      AgentPermissionOperation.read,
    );
    expect(
      describeAgentToolPermission('delete_tag_library_category').operation,
      AgentPermissionOperation.delete,
    );
    for (final toolName in [
      'set_character_layout_mode',
      'reorder_characters',
      'clear_characters',
    ]) {
      expect(
        describeAgentToolPermission(toolName).domain,
        AgentPermissionDomain.prompt,
      );
    }
    expect(
      describeAgentToolPermission('clear_characters').operation,
      AgentPermissionOperation.delete,
    );
    expect(
      describeAgentToolPermission('select_generated_image'),
      isA<AgentToolPermissionDescriptor>()
          .having(
            (value) => value.domain,
            'domain',
            AgentPermissionDomain.appNavigation,
          )
          .having(
            (value) => value.operation,
            'operation',
            AgentPermissionOperation.execute,
          ),
    );
    expect(
      describeAgentToolPermission('open_generation_image_workflow'),
      isA<AgentToolPermissionDescriptor>()
          .having(
            (value) => value.domain,
            'domain',
            AgentPermissionDomain.generation,
          )
          .having(
            (value) => value.operation,
            'operation',
            AgentPermissionOperation.execute,
          )
          .having((value) => value.mayConsumeAnlas, 'mayConsumeAnlas', isFalse),
    );
    expect(
      describeAgentToolPermission('set_generated_image_favorite').domain,
      AgentPermissionDomain.localGallery,
    );
    expect(
      describeAgentToolPermission('save_generated_image'),
      isA<AgentToolPermissionDescriptor>()
          .having((value) => value.domain, 'domain', AgentPermissionDomain.file)
          .having(
            (value) => value.operation,
            'operation',
            AgentPermissionOperation.create,
          ),
    );
    for (final toolName in const [
      'copy_generated_image_to_clipboard',
      'send_generated_image_to_krita',
    ]) {
      expect(
        describeAgentToolPermission(toolName).domain,
        AgentPermissionDomain.externalActions,
      );
    }
  });

  test('image mutations follow safe, ask, and full-access policies', () {
    const toolNames = [
      'select_generated_image',
      'open_generation_image_workflow',
      'set_generated_image_favorite',
      'save_generated_image',
      'copy_generated_image_to_clipboard',
      'send_generated_image_to_krita',
    ];
    final descriptors = [
      for (final name in toolNames) describeAgentToolPermission(name),
    ];
    final catalog = AgentToolPermissionCatalog(
      toolNames: toolNames,
      descriptors: descriptors,
    );

    for (final mode in const {
      AgentAccessMode.readOnly,
      AgentAccessMode.askBeforeWrite,
      AgentAccessMode.allowWrite,
    }) {
      final policy = AgentPermissionPolicy({
        for (final domain in AgentPermissionDomain.values) domain: mode,
      });
      final expected = switch (mode) {
        AgentAccessMode.readOnly => AgentPermissionDecision.block,
        AgentAccessMode.askBeforeWrite => AgentPermissionDecision.ask,
        AgentAccessMode.allowWrite => AgentPermissionDecision.allow,
        AgentAccessMode.blocked => AgentPermissionDecision.block,
      };
      for (final name in toolNames) {
        expect(
          catalog.decide(toolName: name, policy: policy),
          expected,
          reason: '$mode/$name',
        );
      }
    }
  });

  group('AgentPermissionPolicy', () {
    test('defaults omitted domains to blocked', () {
      final policy = AgentPermissionPolicy(const {});

      expect(
        policy.decide(
          AgentPermissionDomain.onlineGallery,
          AgentPermissionOperation.read,
        ),
        AgentPermissionDecision.block,
      );
    });

    test('applies access modes to ordinary operations', () {
      final policy = AgentPermissionPolicy(const {
        AgentPermissionDomain.status: AgentAccessMode.readOnly,
        AgentPermissionDomain.prompt: AgentAccessMode.askBeforeWrite,
        AgentPermissionDomain.settings: AgentAccessMode.allowWrite,
      });

      expect(
        policy.decide(
          AgentPermissionDomain.status,
          AgentPermissionOperation.read,
        ),
        AgentPermissionDecision.allow,
      );
      expect(
        policy.decide(
          AgentPermissionDomain.status,
          AgentPermissionOperation.update,
        ),
        AgentPermissionDecision.block,
      );
      expect(
        policy.decide(
          AgentPermissionDomain.prompt,
          AgentPermissionOperation.create,
        ),
        AgentPermissionDecision.ask,
      );
      expect(
        policy.decide(
          AgentPermissionDomain.settings,
          AgentPermissionOperation.execute,
        ),
        AgentPermissionDecision.allow,
      );
    });

    test('always confirms destructive operations in non-blocked domains', () {
      for (final mode in const {
        AgentAccessMode.askBeforeWrite,
        AgentAccessMode.allowWrite,
      }) {
        final policy = AgentPermissionPolicy({
          AgentPermissionDomain.generationQueue: mode,
        });
        for (final operation in const {
          AgentPermissionOperation.delete,
          AgentPermissionOperation.overwrite,
          AgentPermissionOperation.move,
        }) {
          expect(
            policy.decide(AgentPermissionDomain.generationQueue, operation),
            AgentPermissionDecision.ask,
          );
        }
      }
    });
  });

  group('AgentToolPermissionCatalog', () {
    const read = AgentToolPermissionDescriptor(
      toolName: 'read_status',
      domain: AgentPermissionDomain.status,
      operation: AgentPermissionOperation.read,
    );
    const generate = AgentToolPermissionDescriptor(
      toolName: 'generate',
      domain: AgentPermissionDomain.generation,
      operation: AgentPermissionOperation.execute,
      mayConsumeAnlas: true,
    );

    test('looks up and evaluates registered tool names', () {
      final catalog = AgentToolPermissionCatalog(
        toolNames: const ['read_status', 'generate'],
        descriptors: const [read, generate],
      );

      expect(catalog.descriptorFor('read_status'), same(read));
      final policy = AgentPermissionPolicy(const {
        AgentPermissionDomain.generation: AgentAccessMode.allowWrite,
      });
      expect(
        catalog.decide(toolName: 'generate', policy: policy),
        AgentPermissionDecision.confirmCharge,
      );
      expect(
        catalog.decide(toolName: 'generate', policy: policy, estimatedAnlas: 0),
        AgentPermissionDecision.allow,
      );
      expect(
        catalog.decide(
          toolName: 'generate',
          policy: policy,
          estimatedAnlas: -3,
        ),
        AgentPermissionDecision.block,
      );
      expect(() => catalog.descriptorFor('unknown'), throwsStateError);
    });

    test('applies the permission mode by operation before billing', () {
      const mutation = AgentToolPermissionDescriptor(
        toolName: 'mutate',
        domain: AgentPermissionDomain.prompt,
        operation: AgentPermissionOperation.update,
      );
      const deletion = AgentToolPermissionDescriptor(
        toolName: 'delete',
        domain: AgentPermissionDomain.prompt,
        operation: AgentPermissionOperation.delete,
      );
      final catalog = AgentToolPermissionCatalog(
        toolNames: const ['read_status', 'mutate', 'delete', 'generate'],
        descriptors: const [read, mutation, deletion, generate],
      );

      AgentPermissionPolicy policy(AgentAccessMode mode) =>
          AgentPermissionPolicy({
            AgentPermissionDomain.status: mode,
            AgentPermissionDomain.prompt: mode,
            AgentPermissionDomain.generation: mode,
          });

      final expected = {
        AgentAccessMode.readOnly: const [
          AgentPermissionDecision.allow,
          AgentPermissionDecision.block,
          AgentPermissionDecision.block,
          AgentPermissionDecision.block,
          AgentPermissionDecision.block,
        ],
        AgentAccessMode.askBeforeWrite: const [
          AgentPermissionDecision.allow,
          AgentPermissionDecision.ask,
          AgentPermissionDecision.ask,
          AgentPermissionDecision.ask,
          AgentPermissionDecision.confirmCharge,
        ],
        AgentAccessMode.allowWrite: const [
          AgentPermissionDecision.allow,
          AgentPermissionDecision.allow,
          AgentPermissionDecision.ask,
          AgentPermissionDecision.allow,
          AgentPermissionDecision.confirmCharge,
        ],
      };
      for (final entry in expected.entries) {
        final current = policy(entry.key);
        expect(
          [
            catalog.decide(toolName: 'read_status', policy: current),
            catalog.decide(toolName: 'mutate', policy: current),
            catalog.decide(toolName: 'delete', policy: current),
            catalog.decide(
              toolName: 'generate',
              policy: current,
              estimatedAnlas: 0,
            ),
            catalog.decide(
              toolName: 'generate',
              policy: current,
              estimatedAnlas: 3,
            ),
          ],
          entry.value,
          reason: entry.key.name,
        );
      }
    });

    test('rejects missing, duplicate, and unknown descriptors', () {
      expect(
        () => AgentToolPermissionCatalog(
          toolNames: const ['read_status', 'generate'],
          descriptors: const [read],
        ),
        throwsArgumentError,
      );
      expect(
        () => AgentToolPermissionCatalog(
          toolNames: const ['read_status'],
          descriptors: const [read, read],
        ),
        throwsArgumentError,
      );
      expect(
        () => AgentToolPermissionCatalog(
          toolNames: const ['generate'],
          descriptors: const [read],
        ),
        throwsArgumentError,
      );
    });
  });
}
