#ifndef RUNNER_SECONDARY_PLUGIN_REGISTRANT_H_
#define RUNNER_SECONDARY_PLUGIN_REGISTRANT_H_

#include <flutter/plugin_registry.h>

// Registers only plugins used by the Agent secondary engine. In particular,
// desktop_multi_window must not be registered here: it installs its internal
// per-window plugin after invoking the window-created callback.
void RegisterSecondaryPlugins(flutter::PluginRegistry* registry);

#endif  // RUNNER_SECONDARY_PLUGIN_REGISTRANT_H_
