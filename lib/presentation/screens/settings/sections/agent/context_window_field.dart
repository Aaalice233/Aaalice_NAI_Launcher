import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../core/utils/token_count_format.dart';
import '../../../../../data/models/agent/agent_settings.dart';
import '../../../../agent_settings/providers/agent_settings_provider.dart';
import '../../../../widgets/common/app_toast.dart';

/// 聊天模型的上下文窗口手填项。
///
/// 内置目录认不出模型时窗口为 0，用量指示与压缩会一起失效，这里是唯一出路。
class ContextWindowField extends ConsumerStatefulWidget {
  const ContextWindowField({
    super.key,
    required this.providerId,
    required this.model,
    required this.catalogWindow,
    required this.overrideWindow,
  });

  final String providerId;
  final String model;

  /// 目录（含跨服务商按名回退）推断出的窗口；0 表示推断不出。
  final int catalogWindow;
  final int? overrideWindow;

  @override
  ConsumerState<ContextWindowField> createState() => _ContextWindowFieldState();
}

class _ContextWindowFieldState extends ConsumerState<ContextWindowField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.overrideWindow?.toString() ?? '',
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit();
    });
  }

  @override
  void didUpdateWidget(ContextWindowField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换模型或值被外部改写时重挂输入框；正在编辑则不打断。
    final changedTarget =
        oldWidget.providerId != widget.providerId ||
        oldWidget.model != widget.model;
    if (changedTarget ||
        (!_focus.hasFocus &&
            oldWidget.overrideWindow != widget.overrideWindow)) {
      _controller.text = widget.overrideWindow?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final parsed = raw.isEmpty ? null : int.tryParse(raw);
    if (parsed == widget.overrideWindow) return;
    if (raw.isNotEmpty &&
        (parsed == null ||
            parsed < 1 ||
            parsed > AgentSettings.maxContextWindowTokens)) {
      AppToast.error(context, context.l10n.agentSettings_contextWindowInvalid);
      _controller.text = widget.overrideWindow?.toString() ?? '';
      return;
    }
    _save(parsed);
  }

  Future<void> _save(int? window) async {
    try {
      await ref
          .read(agentSettingsProvider.notifier)
          .setContextWindowOverride(
            providerId: widget.providerId,
            model: widget.model,
            window: window,
          );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        context.l10n.agentSettings_operationFailed(error.toString()),
      );
      _controller.text = widget.overrideWindow?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final known = widget.catalogWindow > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        key: const ValueKey('agent-chat-context-window'),
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.agentSettings_contextWindow,
          hintText: known
              ? formatTokenCount(widget.catalogWindow)
              : l10n.agentSettings_contextWindowUnknownHint,
          helperMaxLines: 3,
          helperText: known
              ? l10n.agentSettings_contextWindowKnown(
                  formatTokenCount(widget.catalogWindow),
                )
              : l10n.agentSettings_contextWindowUnknown,
          suffixIcon: widget.overrideWindow == null
              ? null
              : IconButton(
                  tooltip: l10n.agentSettings_contextWindowReset,
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _submit();
                  },
                ),
        ),
      ),
    );
  }
}
