import 'package:flutter/widgets.dart';

import 'tag_editor_session.dart';

class TagEditorScope extends InheritedNotifier<TagEditorSession> {
  const TagEditorScope({
    super.key,
    required TagEditorSession session,
    required super.child,
  }) : super(notifier: session);
  static TagEditorSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TagEditorScope>()?.notifier;
}
