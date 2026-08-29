/// Tools whose image output is an explicit part of the chat transcript.
const Set<String> agentExplicitMediaToolNames = {
  'display_images',
  'preview_generated_image',
  'generate_image',
  'submit_generation',
};

bool agentToolDisplaysMedia(String toolName) =>
    agentExplicitMediaToolNames.contains(toolName);
