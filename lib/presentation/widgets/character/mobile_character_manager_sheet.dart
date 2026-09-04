import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/character_position_canvas_provider.dart';
import 'inline_character_row.dart';

/// Character manager content presented by [AdaptivePresenter].
///
/// The presenter owns the compact full-screen or wide side-panel surface. This
/// widget keeps the editor selection and back-navigation semantics shared by
/// both presentations.
class MobileCharacterManagerSheet extends ConsumerStatefulWidget {
  const MobileCharacterManagerSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  ConsumerState<MobileCharacterManagerSheet> createState() =>
      _MobileCharacterManagerSheetState();
}

class _MobileCharacterManagerSheetState
    extends ConsumerState<MobileCharacterManagerSheet> {
  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(characterPositionCanvasProvider, (previous, next) {
      if (!next || previous == true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    });

    return SizedBox.expand(
      key: const ValueKey('generation_mobile_character_manager_sheet'),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: const InlineCharacterRow(
          showWhenEmpty: true,
          compactHeader: true,
          managerLayout: true,
        ),
      ),
    );
  }
}
