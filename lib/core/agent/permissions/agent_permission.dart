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

/// How a positive Anlas estimate is approved once the domain allows the call.
enum AgentChargeApproval {
  confirmEach,

  /// Mirrors the generation button: only estimates at or above the high-cost
  /// threshold ask, and no threshold means every known estimate proceeds.
  confirmAtThreshold,
}

class AgentPermissionPolicy {
  AgentPermissionPolicy(
    Map<AgentPermissionDomain, AgentAccessMode> modes, {
    this.chargeApproval = AgentChargeApproval.confirmEach,
  }) : _modes = Map.unmodifiable(modes);

  final Map<AgentPermissionDomain, AgentAccessMode> _modes;

  final AgentChargeApproval chargeApproval;

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
