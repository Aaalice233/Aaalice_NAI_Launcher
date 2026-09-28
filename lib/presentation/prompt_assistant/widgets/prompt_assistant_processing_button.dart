import 'package:flutter/material.dart';

class PromptAssistantProcessingButton extends StatefulWidget {
  const PromptAssistantProcessingButton({
    super.key,
    required this.extent,
    required this.showStop,
    required this.label,
    required this.onCancel,
  });

  final double extent;
  final bool showStop;
  final String label;
  final VoidCallback? onCancel;

  @override
  State<PromptAssistantProcessingButton> createState() =>
      _PromptAssistantProcessingButtonState();
}

class _PromptAssistantProcessingButtonState
    extends State<PromptAssistantProcessingButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final stop = _hovered || _focused;
    return Tooltip(
      message: widget.label,
      child: SizedBox.square(
        dimension: widget.extent,
        child: Focus(
          onFocusChange: (value) => setState(() => _focused = value),
          skipTraversal: true,
          child: IconButton(
            key: const ValueKey('prompt_assistant_stop'),
            onPressed: widget.onCancel,
            onHover: (value) => setState(() => _hovered = value),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              hoverColor: const Color(0x24FFFFFF),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            icon: Semantics(
              label: widget.label,
              child: stop
                  ? const Icon(Icons.stop_rounded, size: 22)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                            value: MediaQuery.disableAnimationsOf(context)
                                ? 0.75
                                : null,
                          ),
                        ),
                        if (widget.showStop)
                          const Icon(Icons.stop_rounded, size: 12),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
