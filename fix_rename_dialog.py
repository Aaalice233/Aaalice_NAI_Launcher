import os

path = "lib/presentation/screens/prompt_config/prompt_config_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "Future<void> _showRenamePresetDialog(pc.RandomPromptPreset preset) async {" in line:
        skip = True
        new_lines.append("  /// 显示重命名预设对话框\n")
        new_lines.append("  Future<void> _showRenamePresetDialog(pc.RandomPromptPreset preset) async {\n")
        new_lines.append("    final newName = await showDialog<String>(\n")
        new_lines.append("      context: context,\n")
        new_lines.append("      builder: (ctx) => _RenamePresetDialog(preset: preset),\n")
        new_lines.append("    );\n")
        new_lines.append("\n")
        new_lines.append("    if (newName != null && newName.isNotEmpty && newName != preset.name) {\n")
        new_lines.append("      final updated = preset.copyWith(name: newName, updatedAt: DateTime.now());\n")
        new_lines.append("      await ref.read(promptConfigNotifierProvider.notifier).updatePreset(updated);\n")
        new_lines.append("    }\n")
        new_lines.append("  }\n")
        continue
    
    if skip:
        if "  String _getConfigSummary(pc.PromptConfig config) {" in line:
            skip = False
            # Add the new StatefulWidget class at the end of the file or here
        else:
            continue
    
    new_lines.append(line)

# Add the StatefulWidget at the end
new_lines.append("\n")
new_lines.append("/// 重命名预设对话框 (StatefulWidget 以管理控制器)\n")
new_lines.append("class _RenamePresetDialog extends StatefulWidget {\n")
new_lines.append("  final pc.RandomPromptPreset preset;\n")
new_lines.append("\n")
new_lines.append("  const _RenamePresetDialog({required this.preset});\n")
new_lines.append("\n")
new_lines.append("  @override\n")
new_lines.append("  State<_RenamePresetDialog> createState() => _RenamePresetDialogState();\n")
new_lines.append("}\n")
new_lines.append("\n")
new_lines.append("class _RenamePresetDialogState extends State<_RenamePresetDialog> {\n")
new_lines.append("  late final TextEditingController _controller;\n")
new_lines.append("\n")
new_lines.append("  @override\n")
new_lines.append("  void initState() {\n")
new_lines.append("    super.initState();\n")
new_lines.append("    _controller = TextEditingController(text: widget.preset.name);\n")
new_lines.append("  }\n")
new_lines.append("\n")
new_lines.append("  @override\n")
new_lines.append("  void dispose() {\n")
new_lines.append("    _controller.dispose();\n")
new_lines.append("    super.dispose();\n")
new_lines.append("  }\n")
new_lines.append("\n")
new_lines.append("  @override\n")
new_lines.append("  Widget build(BuildContext context) {\n")
new_lines.append("    return AlertDialog(\n")
new_lines.append("      title: Text(context.l10n.preset_rename),\n")
new_lines.append("      content: TextField(\n")
new_lines.append("        controller: _controller,\n")
new_lines.append("        autofocus: true,\n")
new_lines.append("        decoration: InputDecoration(\n")
new_lines.append("          labelText: context.l10n.preset_presetName,\n")
new_lines.append("          border: const OutlineInputBorder(),\n")
new_lines.append("        ),\n")
new_lines.append("        onSubmitted: (value) => Navigator.pop(context, value.trim()),\n")
new_lines.append("      ),\n")
new_lines.append("      actions: [\n")
new_lines.append("        TextButton(\n")
new_lines.append("          onPressed: () => Navigator.pop(context),\n")
                    # Note: context is ctx in the original code, but here it's the dialog's context
new_lines.append("          child: Text(context.l10n.common_cancel),\n")
new_lines.append("        ),\n")
new_lines.append("        FilledButton(\n")
new_lines.append("          onPressed: () => Navigator.pop(context, _controller.text.trim()),\n")
new_lines.append("          child: Text(context.l10n.common_confirm),\n")
new_lines.append("        ),\n")
new_lines.append("      ],\n")
new_lines.append("    );\n")
new_lines.append("  }\n")
new_lines.append("}\n")

with open(path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
