import 'package:flutter/material.dart';

import '../../../data/models/agent/agent_settings.dart';

/// Applies Agent-only reading preferences without changing the app-wide theme.
class AgentChatReadingPreferences extends StatelessWidget {
  const AgentChatReadingPreferences({
    super.key,
    required this.config,
    required this.desktop,
    required this.child,
  });

  static const desktopBaselineScale = 1.15;

  final AgentChatConfig config;
  final bool desktop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final visualDensity = config.density == AgentChatDensity.compact
        ? const VisualDensity(horizontal: -1, vertical: -1)
        : VisualDensity.standard;

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: _AgentReadingTextScaler(
          mediaQuery.textScaler,
          config.readingTextScale,
          minimumFactor: desktop ? desktopBaselineScale : 0.8,
        ),
      ),
      child: Theme(
        data: theme.copyWith(visualDensity: visualDensity),
        child: KeyedSubtree(
          key: const ValueKey('agent-chat-reading-preferences'),
          child: child,
        ),
      ),
    );
  }
}

final class _AgentReadingTextScaler extends TextScaler {
  const _AgentReadingTextScaler(
    this.delegate,
    this.factor, {
    required this.minimumFactor,
  });

  final TextScaler delegate;
  final double factor;
  final double minimumFactor;

  double _scaledValue(double fontSize) => (delegate.scale(fontSize) * factor)
      .clamp(fontSize * minimumFactor, fontSize * 3.0)
      .toDouble();

  @override
  double scale(double fontSize) => _scaledValue(fontSize);

  @override
  double get textScaleFactor => _scaledValue(1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AgentReadingTextScaler &&
          other.delegate == delegate &&
          other.factor == factor &&
          other.minimumFactor == minimumFactor;

  @override
  int get hashCode => Object.hash(delegate, factor, minimumFactor);
}
