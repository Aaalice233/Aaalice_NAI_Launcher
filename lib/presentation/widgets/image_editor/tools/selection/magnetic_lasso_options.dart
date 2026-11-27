import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../tool_setting_rows.dart';
import 'magnetic_lasso_selection_tool.dart';

/// 磁性套索的吸附参数及键盘操作的触屏入口。
class MagneticLassoOptions extends StatefulWidget {
  const MagneticLassoOptions({
    super.key,
    required this.tool,
    required this.state,
  });

  final MagneticLassoSelectionTool tool;
  final EditorState state;

  @override
  State<MagneticLassoOptions> createState() => _MagneticLassoOptionsState();
}

class _MagneticLassoOptionsState extends State<MagneticLassoOptions> {
  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final state = widget.state;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolSettingRows(
          rows: [
            ToolSettingRow.slider(
              label: l10n.editor_magneticLassoWidth,
              value: tool.width.toDouble(),
              min: 1,
              max: 40,
              divisions: 39,
              onChanged: (value) => setState(
                () => tool.updateOptions(state, width: value.round()),
              ),
            ),
            ToolSettingRow.slider(
              label: l10n.editor_magneticLassoContrast,
              value: tool.contrast.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              suffix: '%',
              onChanged: (value) => setState(
                () => tool.updateOptions(state, contrast: value.round()),
              ),
            ),
            ToolSettingRow.slider(
              label: l10n.editor_magneticLassoFrequency,
              value: tool.frequency.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (value) => setState(
                () => tool.updateOptions(state, frequency: value.round()),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListenableBuilder(
            listenable: tool.anchorListenable,
            builder: (context, _) =>
                _LassoPathActions(tool: tool, state: state),
          ),
        ),
      ],
    );
  }
}

class _LassoPathActions extends StatelessWidget {
  const _LassoPathActions({required this.tool, required this.state});

  final MagneticLassoSelectionTool tool;
  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final anchors = tool.anchorCount;
    final l10n = context.l10n;
    final style = TextButton.styleFrom(minimumSize: const Size(44, 44));
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: anchors > 0 ? () => tool.onEscape(state) : null,
          style: style,
          child: Text(l10n.common_cancel),
        ),
        TextButton(
          onPressed: anchors > 0 ? () => tool.onDeleteKey(state) : null,
          style: style,
          child: Text(l10n.editor_magneticLassoRemoveAnchor),
        ),
        FilledButton.tonal(
          onPressed: anchors >= 3 ? () => tool.onConfirm(state) : null,
          style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
          child: Text(l10n.editor_magneticLassoClose),
        ),
      ],
    );
  }
}
