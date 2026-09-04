enum AgentToolMediaPresentation { none, modelOnly, conversation }

/// Product-level presentation rules for tool media in persisted transcripts.
const Map<String, AgentToolMediaPresentation> agentToolMediaPresentation = {
  'inspect_images': AgentToolMediaPresentation.modelOnly,
  'display_images': AgentToolMediaPresentation.conversation,
  'generate_image': AgentToolMediaPresentation.conversation,
  'submit_generation': AgentToolMediaPresentation.conversation,

  // Historical conversations used this tool as an explicit display action.
  'preview_generated_image': AgentToolMediaPresentation.conversation,
};

bool agentToolDisplaysMedia(String toolName) =>
    agentToolMediaPresentation[toolName] ==
    AgentToolMediaPresentation.conversation;
