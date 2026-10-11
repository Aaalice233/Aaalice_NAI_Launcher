import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../utils/dropped_file_reader.dart';
import '../../widgets/drop/image_paste_shortcuts.dart';
import '../services/agent_chat_inline_image_policy.dart';

class _AgentChatPasteIntent extends Intent {
  const _AgentChatPasteIntent();
}

/// 输入框内的粘贴：剪贴板取到图片就作为附件，否则交还系统文本粘贴。
///
/// 它比全局粘贴更靠近焦点，按键先到这里，图片不会被送去生成页的用途选择。
class AgentChatImagePasteScope extends StatelessWidget {
  const AgentChatImagePasteScope({
    super.key,
    required this.onPasteImage,
    required this.child,
  });

  final Future<bool> Function() onPasteImage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: imagePasteShortcuts(const _AgentChatPasteIntent()),
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AgentChatPasteIntent: CallbackAction<_AgentChatPasteIntent>(
            onInvoke: (_) {
              final fallbackTextPaste = textPasteFallbackFor(
                FocusManager.instance.primaryFocus?.context,
              );
              unawaited(_paste(fallbackTextPaste));
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }

  Future<void> _paste(VoidCallback? fallbackTextPaste) async {
    if (await onPasteImage()) return;
    fallbackTextPaste?.call();
  }
}

/// 安卓输入法（Gboard 剪贴板、图片键盘）递交的图片走与粘贴相同的附件准入。
ContentInsertionConfiguration agentChatKeyboardImageInsertion(
  Future<void> Function(List<DroppedFileData> files) attachImageFiles,
) {
  return ContentInsertionConfiguration(
    allowedMimeTypes: AgentChatInlineImagePolicy.mimeTypes,
    onContentInserted: (content) => unawaited(
      attachImageFiles([
        DroppedFileData(
          fileName: _keyboardImageName(content),
          bytes: content.data ?? Uint8List(0),
        ),
      ]),
    ),
  );
}

String _keyboardImageName(KeyboardInsertedContent content) {
  final segment = Uri.tryParse(content.uri)?.pathSegments.lastOrNull;
  if (segment != null && segment.contains('.')) return segment;
  return 'image.${content.mimeType.split('/').last}';
}
