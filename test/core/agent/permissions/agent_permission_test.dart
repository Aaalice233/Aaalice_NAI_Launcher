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

    test('always confirms destructive and charged operations', () {
      for (final mode in AgentAccessMode.values) {
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
        expect(
          policy.decide(
            AgentPermissionDomain.generationQueue,
            AgentPermissionOperation.charge,
          ),
          AgentPermissionDecision.confirmCharge,
        );
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
      operation: AgentPermissionOperation.charge,
    );

    test('looks up and evaluates registered tool names', () {
      final catalog = AgentToolPermissionCatalog(
        toolNames: const ['read_status', 'generate'],
        descriptors: const [read, generate],
      );

      expect(catalog.descriptorFor('read_status'), same(read));
      expect(
        catalog.decide(
          toolName: 'generate',
          policy: AgentPermissionPolicy(const {
            AgentPermissionDomain.generation: AgentAccessMode.allowWrite,
          }),
        ),
        AgentPermissionDecision.confirmCharge,
      );
      expect(() => catalog.descriptorFor('unknown'), throwsStateError);
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
