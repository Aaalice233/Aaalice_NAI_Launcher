import 'agent_permission.dart';

class AgentToolPermissionDescriptor {
  const AgentToolPermissionDescriptor({
    required this.toolName,
    required this.domain,
    required this.operation,
    this.mayConsumeAnlas = false,
  });

  final String toolName;
  final AgentPermissionDomain domain;
  final AgentPermissionOperation operation;
  final bool mayConsumeAnlas;
}

/// Complete, immutable permission metadata for a known set of tools.
class AgentToolPermissionCatalog {
  AgentToolPermissionCatalog({
    required Iterable<String> toolNames,
    required Iterable<AgentToolPermissionDescriptor> descriptors,
  }) : _byName = _build(toolNames, descriptors);

  final Map<String, AgentToolPermissionDescriptor> _byName;

  Iterable<String> get toolNames => _byName.keys;

  AgentToolPermissionDescriptor descriptorFor(String toolName) {
    final descriptor = _byName[toolName];
    if (descriptor == null) {
      throw StateError('Tool "$toolName" has no permission descriptor.');
    }
    return descriptor;
  }

  AgentPermissionDecision decide({
    required String toolName,
    required AgentPermissionPolicy policy,
    int? estimatedAnlas,
  }) {
    final descriptor = descriptorFor(toolName);
    final ordinaryDecision = policy.decide(
      descriptor.domain,
      descriptor.operation,
    );
    if (ordinaryDecision == AgentPermissionDecision.block ||
        !descriptor.mayConsumeAnlas) {
      return ordinaryDecision;
    }
    if (estimatedAnlas != null && estimatedAnlas < 0) {
      return AgentPermissionDecision.block;
    }
    if (estimatedAnlas == 0) return ordinaryDecision;
    return AgentPermissionDecision.confirmCharge;
  }

  static Map<String, AgentToolPermissionDescriptor> _build(
    Iterable<String> toolNames,
    Iterable<AgentToolPermissionDescriptor> descriptors,
  ) {
    final expected = <String>{};
    for (final name in toolNames) {
      _validateName(name);
      if (!expected.add(name)) {
        throw ArgumentError.value(name, 'toolNames', 'Duplicate tool name');
      }
    }

    final result = <String, AgentToolPermissionDescriptor>{};
    for (final descriptor in descriptors) {
      _validateName(descriptor.toolName);
      if (!expected.contains(descriptor.toolName)) {
        throw ArgumentError.value(
          descriptor.toolName,
          'descriptors',
          'Descriptor refers to an unknown tool',
        );
      }
      if (result.containsKey(descriptor.toolName)) {
        throw ArgumentError.value(
          descriptor.toolName,
          'descriptors',
          'Duplicate permission descriptor',
        );
      }
      result[descriptor.toolName] = descriptor;
    }

    final missing = expected.difference(result.keys.toSet());
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Missing permission descriptors for: ${missing.toList()..sort()}',
      );
    }
    return Map.unmodifiable(result);
  }

  static void _validateName(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'toolName', 'Must not be empty');
    }
  }
}

AgentToolPermissionDescriptor describeAgentToolPermission(String toolName) {
  const reads = {
    'get_application_context',
    'list_fixed_tags',
    'list_tag_library_entries',
    'get_local_gallery_detail',
    'get_online_gallery_detail',
    'search_local_gallery',
    'search_online_gallery',
    'get_generation_settings',
    'get_generation_status',
    'get_recent_images',
    'preview_generated_image',
    'display_images',
    'inspect_generation_preparation',
    'get_manual_inpaint_draft',
    'list_manual_inpaint_drafts',
    'get_prompt_state',
    'get_skill_diagnostics',
    'read_skill',
    'read_skill_resource',
    'get_active_generation_references',
    'get_vibe_library_entry',
    'preview_vibe_library_entry',
    'get_precise_reference_entry',
    'preview_precise_reference_entry',
    'list_precise_reference_library',
    'list_vibe_library',
    'get_fixed_tag',
    'list_fixed_tag_categories',
    'get_tag_library_entry',
    'preview_local_gallery_image',
    'preview_online_gallery_media',
    'inspect_generation_queue',
    'inspect_generation_queue_task',
    'search_tags',
    'web_read',
    'web_search',
    'read',
    'interrogate_image',
  };
  const charged = {
    'generate_image',
    'queue_image_task',
    'submit_generation',
    'submit_manual_inpaint_draft',
    'start_generation_queue',
    'resume_generation_queue',
  };
  const destructive = {
    'delete_fixed_tag',
    'delete_tag_library_entry',
    'delete_precise_reference_entry',
    'delete_vibe_library_entry',
    'cancel_generation_preparation',
    'cancel_manual_inpaint_draft',
    'remove_character',
    'remove_active_precise_reference',
    'remove_active_vibe',
    'delete_generation_queue_task',
    'clear_failed_generation_queue_tasks',
    'clear_completed_generation_queue_tasks',
  };

  final domain = switch (toolName) {
    'get_application_context' ||
    'navigate_application' ||
    'select_generated_image' => AgentPermissionDomain.appNavigation,
    'set_generated_image_favorite' => AgentPermissionDomain.localGallery,
    'save_generated_image' => AgentPermissionDomain.file,
    'copy_generated_image_to_clipboard' ||
    'send_generated_image_to_krita' => AgentPermissionDomain.externalActions,
    String()
        when toolName.contains('fixed_tag') ||
            toolName.contains('tag_library') =>
      AgentPermissionDomain.tagAndFixedTags,
    String() when toolName.contains('online_gallery') =>
      AgentPermissionDomain.onlineGallery,
    String() when toolName.contains('local_gallery') =>
      AgentPermissionDomain.localGallery,
    String() when toolName.contains('vibe') =>
      AgentPermissionDomain.vibeLibrary,
    String() when toolName.contains('precise_ref') =>
      AgentPermissionDomain.preciseRefLibrary,
    String() when toolName.contains('inpaint') => AgentPermissionDomain.inpaint,
    'queue_image_task' ||
    'get_generation_status' => AgentPermissionDomain.generationQueue,
    String() when toolName.contains('generation_queue') =>
      AgentPermissionDomain.generationQueue,
    String()
        when toolName.contains('generation') ||
            toolName == 'generate_image' ||
            toolName == 'get_recent_images' ||
            toolName == 'preview_generated_image' ||
            toolName == 'display_images' ||
            toolName == 'interrogate_image' =>
      AgentPermissionDomain.generation,
    'get_prompt_state' ||
    'set_positive_prompt' ||
    'set_negative_prompt' ||
    'add_character' ||
    'update_character' ||
    'remove_character' ||
    'set_character_layout_mode' ||
    'reorder_characters' ||
    'clear_characters' => AgentPermissionDomain.prompt,
    'read_skill' ||
    'read_skill_resource' ||
    'reload_skills' ||
    'get_skill_diagnostics' => AgentPermissionDomain.skills,
    'web_read' || 'web_search' => AgentPermissionDomain.web,
    'read' || 'interrogate_image' => AgentPermissionDomain.file,
    'search_tags' => AgentPermissionDomain.tagAndFixedTags,
    _ => throw StateError('Tool "$toolName" has no permission domain.'),
  };
  final isRead =
      reads.contains(toolName) ||
      toolName.startsWith('get_') ||
      toolName.startsWith('list_') ||
      toolName.startsWith('search_') ||
      toolName.startsWith('inspect_') ||
      toolName.startsWith('preview_') ||
      toolName.startsWith('browse_') ||
      toolName.startsWith('read_');
  final isDelete =
      destructive.contains(toolName) ||
      toolName.startsWith('delete_') ||
      toolName.startsWith('remove_') ||
      toolName.startsWith('clear_') ||
      toolName.startsWith('cancel_');
  final operation = switch (toolName) {
    'save_generated_image' => AgentPermissionOperation.create,
    'navigate_application' ||
    'select_generated_image' ||
    'open_generation_image_workflow' ||
    'load_inpaint_draft_into_panel' ||
    'copy_generated_image_to_clipboard' ||
    'send_generated_image_to_krita' => AgentPermissionOperation.execute,
    _ when isDelete => AgentPermissionOperation.delete,
    _ when isRead => AgentPermissionOperation.read,
    _ when toolName.startsWith('create_') || toolName.startsWith('prepare_') =>
      AgentPermissionOperation.create,
    _ => AgentPermissionOperation.update,
  };
  return AgentToolPermissionDescriptor(
    toolName: toolName,
    domain: domain,
    operation: operation,
    mayConsumeAnlas: charged.contains(toolName),
  );
}

AgentPermissionPolicy agentPermissionPolicy({
  required bool safeMode,
  required bool fullAccess,
}) {
  final mode = fullAccess
      ? AgentAccessMode.allowWrite
      : safeMode
      ? AgentAccessMode.readOnly
      : AgentAccessMode.askBeforeWrite;
  return AgentPermissionPolicy({
    for (final domain in AgentPermissionDomain.values) domain: mode,
  });
}
