import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/character_position_canvas_provider.dart';
import '../../providers/character_prompt_provider.dart';
import 'inline_character_row.dart';

/// Phone-first character manager used by the fullscreen prompt workbench.
///
/// The resting height keeps the character overview readable without pretending
/// to be a full page. Opening an editor promotes the sheet to its full working
/// height, while the shared scroll controller keeps dragging and content
/// scrolling continuous.
class MobileCharacterManagerSheet extends ConsumerStatefulWidget {
  const MobileCharacterManagerSheet({super.key});

  @override
  ConsumerState<MobileCharacterManagerSheet> createState() =>
      _MobileCharacterManagerSheetState();
}

class _MobileCharacterManagerSheetState
    extends ConsumerState<MobileCharacterManagerSheet> {
  static const _overviewExtent = 0.62;
  static const _editorExtent = 0.92;

  final _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final characters = ref.read(characterPromptNotifierProvider).characters;
      if (characters.length != 1) return;
      ref
          .read(selectedCharacterIdProvider.notifier)
          .select(characters.single.id);
      _expandToEditor();
    });
  }

  void _expandToEditor() {
    if (!mounted) return;
    if (!_sheetController.isAttached) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _expandToEditor());
      return;
    }
    _sheetController.animateTo(
      _editorExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<String?>(selectedCharacterIdProvider, (previous, next) {
      if (next == null || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _expandToEditor());
    });
    ref.listen<bool>(characterPositionCanvasProvider, (previous, next) {
      if (!next || previous == true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    });

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        key: const ValueKey('generation_mobile_character_manager_sheet'),
        controller: _sheetController,
        expand: false,
        initialChildSize: _overviewExtent,
        minChildSize: 0.44,
        maxChildSize: _editorExtent,
        snap: true,
        snapSizes: const [_overviewExtent, _editorExtent],
        builder: (context, scrollController) => Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.prompt_characterPrompts,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: const InlineCharacterRow(
                    showWhenEmpty: true,
                    compactHeader: true,
                    managerLayout: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
