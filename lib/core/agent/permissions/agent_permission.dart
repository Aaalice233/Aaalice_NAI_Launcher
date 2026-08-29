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
    final mode = modeFor(domain);
    if (mode == AgentAccessMode.blocked) {
      return AgentPermissionDecision.block;
    }
    if (mode == AgentAccessMode.readOnly &&
        operation != AgentPermissionOperation.read) {
      return AgentPermissionDecision.block;
    }
    // Destructive actions retain an explicit confirmation even in full-access
    // mode. Billing is evaluated separately from the operation because a tool
    // that can consume Anlas may have an exact zero-cost invocation.
    if (_destructiveOperations.contains(operation)) {
      return AgentPermissionDecision.ask;
    }
    return switch (mode) {
      AgentAccessMode.blocked => AgentPermissionDecision.block,
      AgentAccessMode.readOnly =>
        operation == AgentPermissionOperation.read
            ? AgentPermissionDecision.allow
            : AgentPermissionDecision.block,
      AgentAccessMode.askBeforeWrite =>
        operation == AgentPermissionOperation.read
            ? AgentPermissionDecision.allow
            : AgentPermissionDecision.ask,
      AgentAccessMode.allowWrite => AgentPermissionDecision.allow,
    };
  }
}

const _destructiveOperations = {
  AgentPermissionOperation.delete,
  AgentPermissionOperation.overwrite,
  AgentPermissionOperation.move,
};
