import 'package:flutter/material.dart';

import '../../../data/models/agent/agent_settings.dart';

/// Applies Agent-only reading preferences without changing the app-wide theme.
class AgentChatReadingPreferences extends StatelessWidget {
  const AgentChatReadingPreferences({
    super.key,
    required this.config,
    required this.child,
  });

  final AgentChatConfig config;
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
  const _AgentReadingTextScaler(this.delegate, this.factor);

  final TextScaler delegate;
  final double factor;

  @override
  double scale(double fontSize) => (delegate.scale(fontSize) * factor)
      .clamp(fontSize * 0.8, fontSize * 3.0)
      .toDouble();

  @override
  double get textScaleFactor =>
      (delegate.scale(1) * factor).clamp(0.8, 3.0).toDouble();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AgentReadingTextScaler &&
          other.delegate == delegate &&
          other.factor == factor;

  @override
  int get hashCode => Object.hash(delegate, factor);
}
