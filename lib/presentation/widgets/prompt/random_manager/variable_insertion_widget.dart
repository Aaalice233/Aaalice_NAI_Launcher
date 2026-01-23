import 'package:flutter/material.dart';

class VariableInsertionWidget extends StatelessWidget {
  final TextEditingController? controller;
  final List<String> variables;
  final VoidCallback? onInserted;

  const VariableInsertionWidget({
    super.key,
    required this.controller,
    this.variables = const ['hair', 'eye', 'clothes', 'pose', 'expression', 'action', 'style'],
    this.onInserted,
  });

  void _insertVariable(BuildContext context, String variable) {
    final activeController = controller;
    if (activeController == null) return;

    final text = activeController.text;
    final selection = activeController.selection;
    final insertText = '__${variable}__';

    int start = selection.start;
    int end = selection.end;

    // Handle invalid selection (e.g., -1) by appending to end
    if (start < 0) {
      start = text.length;
      end = text.length;
    }

    // Ensure start <= end
    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    final newText = text.replaceRange(start, end, insertText);
    
    activeController.value = activeController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );
    
    onInserted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = controller != null;
    
    // Horizontal Strip (Input Accessory Style)
    return Container(
      height: 44, // Slightly taller for touch targets
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: variables.length + 1, // +1 for label/icon
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.data_array,
                      size: 16,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Vars:",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final variable = variables[index - 1];
          return Center(child: _buildChip(context, variable, isEnabled));
        },
      ),
    );
  }

  Widget _buildChip(BuildContext context, String variable, bool isEnabled) {
    final theme = Theme.of(context);
    
    return Tooltip(
      message: isEnabled ? 'Insert __${variable}__' : 'Select a field',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? () => _insertVariable(context, variable) : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isEnabled 
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.transparent, 
              ),
            ),
            child: Text(
              variable,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
                color: isEnabled 
                    ? theme.colorScheme.onSurfaceVariant 
                    : theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
