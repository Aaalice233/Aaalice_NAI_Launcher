/// Application capability controlled by the agent permission system.
enum AgentPermissionDomain {
  appNavigation,
  tagAndFixedTags,
  onlineGallery,
  localGallery,
  vibeLibrary,
  preciseRefLibrary,
  inpaint,
  generationQueue,
  prompt,
  generation,
  settings,
  status,
  skills,
  web,
  file,
  externalActions,
}

/// Access granted to tools in one [AgentPermissionDomain].
enum AgentAccessMode { blocked, readOnly, askBeforeWrite, allowWrite }

/// The effect a tool invocation can have.
enum AgentPermissionOperation {
  read,
  create,
  update,
  delete,
  overwrite,
  move,
  execute,
}

/// Action the caller must take before invoking a tool.
enum AgentPermissionDecision { allow, block, ask, confirmCharge }

class AgentPermissionPolicy {
  AgentPermissionPolicy(Map<AgentPermissionDomain, AgentAccessMode> modes)
    : _modes = Map.unmodifiable(modes);

  final Map<AgentPermissionDomain, AgentAccessMode> _modes;

  Map<AgentPermissionDomain, AgentAccessMode> get modes => _modes;

  /// Unconfigured domains are denied rather than inheriting ambient access.
  AgentAccessMode modeFor(AgentPermissionDomain domain) =>
      _modes[domain] ?? AgentAccessMode.blocked;

  AgentPermissionDecision decide(
    AgentPermissionDomain domain,
    AgentPermissionOperation operation,
  ) {
    // Billing stays with the catalog: a chargeable tool can still cost zero.
    final isRead = operation == AgentPermissionOperation.read;
    return switch (modeFor(domain)) {
      AgentAccessMode.blocked => AgentPermissionDecision.block,
      AgentAccessMode.readOnly =>
        isRead ? AgentPermissionDecision.allow : AgentPermissionDecision.block,
      AgentAccessMode.askBeforeWrite =>
        isRead ? AgentPermissionDecision.allow : AgentPermissionDecision.ask,
      AgentAccessMode.allowWrite => AgentPermissionDecision.allow,
    };
  }
}
