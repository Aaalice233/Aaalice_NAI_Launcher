import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/interaction/user_question.dart';
import '../../themes/core/layered_surface_style.dart';

/// Reusable, sequential question form. It does not know about agents or tools.
class UserQuestionFlow extends StatefulWidget {
  const UserQuestionFlow({
    super.key,
    required this.questions,
    required this.onSubmit,
    required this.onCancel,
    this.expiresAt,
  });

  final DateTime? expiresAt;
  final List<UserQuestion> questions;
  final ValueChanged<List<UserQuestionAnswer>> onSubmit;
  final VoidCallback onCancel;

  @override
  State<UserQuestionFlow> createState() => _UserQuestionFlowState();
}

class _UserQuestionFlowState extends State<UserQuestionFlow> {
  late final List<UserQuestionAnswer?> _answers = List.filled(
    widget.questions.length,
    null,
  );
  final _customController = TextEditingController();
  final _scrollController = ScrollController();
  int _index = 0;
  bool _custom = false;
  bool _submitted = false;

  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(UserQuestionFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _startCountdown();
  }

  void _startCountdown() {
    _countdown?.cancel();
    if (widget.expiresAt == null) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!DateTime.now().isBefore(widget.expiresAt!)) timer.cancel();
      setState(() {});
    });
  }

  String get _remainingTime {
    final seconds = math.max(
      0,
      (widget.expiresAt!.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil(),
    );
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  bool get _reviewing => _index == widget.questions.length;

  @override
  void dispose() {
    _countdown?.cancel();
    _customController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _index = index;
      final answer = _reviewing ? null : _answers[index];
      _custom = answer?.customText != null;
      _customController.text = answer?.customText ?? '';
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _choose(UserQuestionAnswer answer) {
    if (_submitted) return;
    _answers[_index] = answer;
    _goTo(_index + 1);
  }

  void _submit() {
    if (_submitted || _answers.any((answer) => answer == null)) return;
    setState(() => _submitted = true);
    widget.onSubmit(_answers.cast<UserQuestionAnswer>());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        key: const ValueKey('user-question-card'),
        color: sectionSurfaceColor(theme.colorScheme),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: math.min(480, constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _reviewing
                                ? l10n.userQuestion_review
                                : l10n.userQuestion_progress(
                                    _index + 1,
                                    widget.questions.length,
                                  ),
                            style: theme.textTheme.labelMedium,
                          ),
                          if (widget.expiresAt != null)
                            Text(
                              l10n.userQuestion_timeout(_remainingTime),
                              key: const ValueKey('user-question-countdown'),
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 8),
                          if (_reviewing)
                            ..._review(context)
                          else
                            ..._question(context),
                        ],
                      ),
                    ),
                  ),
                ),
                // Keep actions reachable independently of long options. Extreme
                // text scaling may scroll the footer within its own allocation.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.min(480, constraints.maxHeight) * 0.4,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: _actions(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      key: const ValueKey('user-question-actions'),
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          key: const ValueKey('user-question-cancel'),
          onPressed: _submitted ? null : widget.onCancel,
          child: Text(l10n.common_cancel),
        ),
        if (_index > 0)
          TextButton(
            onPressed: _submitted ? null : () => _goTo(_index - 1),
            child: Text(l10n.userQuestion_previous),
          ),
        if (_reviewing)
          FilledButton(
            key: const ValueKey('user-question-submit'),
            onPressed: _submitted ? null : _submit,
            child: Text(l10n.userQuestion_submit),
          )
        else if (_custom)
          FilledButton(
            key: const ValueKey('user-question-next'),
            onPressed: _customController.text.trim().isEmpty
                ? null
                : () => _choose(
                    UserQuestionAnswer.custom(_customController.text.trim()),
                  ),
            child: Text(l10n.userQuestion_next),
          ),
      ],
    );
  }

  List<Widget> _question(BuildContext context) {
    final question = widget.questions[_index];
    final l10n = context.l10n;
    return [
      Text(question.title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      for (final option in question.options)
        _QuestionOption(
          key: ValueKey('user-question-option-${question.id}-${option.id}'),
          label: option.label,
          description: option.description,
          recommended: option.id == question.recommendedOptionId,
          selected: !_custom && _answers[_index]?.optionId == option.id,
          onTap: () => _choose(UserQuestionAnswer.option(option.id)),
        ),
      _QuestionOption(
        key: const ValueKey('user-question-custom-option'),
        label: l10n.userQuestion_custom,
        description: l10n.userQuestion_customDescription,
        recommended: false,
        selected: _custom,
        onTap: () => setState(() => _custom = true),
      ),
      if (_custom)
        TextField(
          key: const ValueKey('user-question-custom-input'),
          controller: _customController,
          minLines: 2,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(labelText: l10n.userQuestion_custom),
        ),
    ];
  }

  List<Widget> _review(BuildContext context) => [
    for (var index = 0; index < widget.questions.length; index++)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.questions[index].title),
          subtitle: Text(
            _answers[index]!.toJson(widget.questions[index])['answer']
                as String,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: _submitted ? null : () => _goTo(index),
        ),
      ),
  ];
}

class _QuestionOption extends StatelessWidget {
  const _QuestionOption({
    super.key,
    required this.label,
    required this.description,
    required this.recommended,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? theme.colorScheme.secondaryContainer
              : controlSurfaceColor(theme.colorScheme),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(label, style: theme.textTheme.titleSmall),
                      if (recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.l10n.userQuestion_recommended,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
