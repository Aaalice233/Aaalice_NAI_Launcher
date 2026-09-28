import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import 'tag_editor_scope.dart';

ContextMenuButtonItem? promptTextSelectionEnabledAction(
  BuildContext context,
  EditableTextState editable,
) {
  if (editable.widget.readOnly) return null;
  final session = TagEditorScope.maybeOf(editable.context);
  final tags = session?.textSelectionTags;
  if (session == null || tags == null || tags.isEmpty) return null;
  final enable = tags.every((tag) => tag.span.disabled);
  return ContextMenuButtonItem(
    label: enable ? context.l10n.tagMode_enable : context.l10n.tagMode_disable,
    onPressed: () {
      editable.hideToolbar();
      session.setTextSelectionEnabled(enable);
    },
  );
}
