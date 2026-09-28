import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mobile workspaces that temporarily own the full screen and hide shell chrome.
enum MobileShellOverlay { promptEditor, agentChat }

class MobileShellOverlayNotifier extends Notifier<Set<MobileShellOverlay>> {
  @override
  Set<MobileShellOverlay> build() => const {};

  void setActive(MobileShellOverlay overlay, bool active) {
    if (active == state.contains(overlay)) return;
    state = active ? {...state, overlay} : ({...state}..remove(overlay));
  }

  void clearGenerationOverlays() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final mobileShellOverlayNotifierProvider =
    NotifierProvider<MobileShellOverlayNotifier, Set<MobileShellOverlay>>(
      MobileShellOverlayNotifier.new,
    );
