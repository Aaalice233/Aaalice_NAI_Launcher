import 'package:flutter/material.dart';

/// Shared responsive contract for every Agent chat host: the docked right
/// panel, the shell side panel, the in-app floating window and full screen.
enum AgentChatWidthClass { compact, regular, wide }

@immutable
class AgentChatLayoutContract {
  const AgentChatLayoutContract._();

  static AgentChatWidthClass widthClassFor(double width) {
    if (width < 420) return AgentChatWidthClass.compact;
    if (width < 760) return AgentChatWidthClass.regular;
    return AgentChatWidthClass.wide;
  }

  static double transcriptHorizontalPadding(double width) =>
      switch (widthClassFor(width)) {
        AgentChatWidthClass.compact => 12,
        AgentChatWidthClass.regular => 16,
        AgentChatWidthClass.wide => 24,
      };

  static double transcriptMaxWidth(double width) =>
      switch (widthClassFor(width)) {
        AgentChatWidthClass.compact => width,
        AgentChatWidthClass.regular => 680,
        AgentChatWidthClass.wide => 820,
      };

  static double userBubbleMaxWidth(double width) {
    final available = width - transcriptHorizontalPadding(width) * 2;
    final fraction = switch (widthClassFor(width)) {
      AgentChatWidthClass.compact => 0.82,
      AgentChatWidthClass.regular => 0.72,
      AgentChatWidthClass.wide => 0.64,
    };
    return (available * fraction).clamp(44.0, 560.0);
  }

  static double assistantMaxWidth(double width) =>
      switch (widthClassFor(width)) {
        AgentChatWidthClass.compact => width,
        AgentChatWidthClass.regular => 660,
        AgentChatWidthClass.wide => 760,
      };

  static bool stackComposerControls(double width, {required bool running}) =>
      width < (running ? 820 : 680);

  static EdgeInsets composerOuterPadding(double width) =>
      EdgeInsets.fromLTRB(width < 420 ? 10 : 14, 6, width < 420 ? 10 : 14, 10);
}
