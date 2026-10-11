import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A focus request that survives until a chat surface mounts and consumes it.
class AgentChatFocusRequest extends ChangeNotifier {
  bool _pending = false;

  bool get pending => _pending;

  void request() {
    _pending = true;
    notifyListeners();
  }

  bool consume() {
    final pending = _pending;
    _pending = false;
    return pending;
  }
}

abstract interface class AgentChatDockHost {
  /// Whether an expanded right panel fits the current workspace constraints,
  /// independent of the user's collapsed state.
  bool get fitsExpanded;
}

/// Runtime-only registry of the surfaces that can present Agent chat.
class AgentChatSurfaceRegistry {
  AgentChatDockHost? _dockHost;

  final AgentChatFocusRequest dockedFocus = AgentChatFocusRequest();
  final AgentChatFocusRequest floatingFocus = AgentChatFocusRequest();

  bool get dockFitsExpanded => _dockHost?.fitsExpanded ?? false;

  void attachDockHost(AgentChatDockHost host) => _dockHost = host;

  void detachDockHost(AgentChatDockHost host) {
    if (identical(_dockHost, host)) _dockHost = null;
  }

  void dispose() {
    dockedFocus.dispose();
    floatingFocus.dispose();
  }
}

final agentChatSurfaceRegistryProvider = Provider<AgentChatSurfaceRegistry>((
  ref,
) {
  final registry = AgentChatSurfaceRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});
