import 'package:flutter/material.dart';

import '../../core/utils/localization_extension.dart';

/// The action row below a form: [leading] actions, cancel, then [primary],
/// aligned to the end edge at the full width of the footer slot.
class AdaptiveFormFooter extends StatelessWidget {
  const AdaptiveFormFooter({
    super.key,
    this.primary,
    this.leading = const [],
    this.cancelLabel,
    this.onCancel,
    this.cancelEnabled = true,
  });

  /// Omit when the form can only be closed.
  final Widget? primary;
  final List<Widget> leading;

  /// Defaults to the localized cancel label.
  final String? cancelLabel;

  /// Defaults to closing the current route.
  final VoidCallback? onCancel;
  final bool cancelEnabled;

  static const _padding = EdgeInsets.fromLTRB(16, 12, 16, 16);

  @override
  Widget build(BuildContext context) {
    final primary = this.primary;
    return SafeArea(
      top: false,
      minimum: _padding,
      // With an alignment the bar always takes the full width, so a loose
      // parent cannot shrink it and pull the buttons to the centre.
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: 8,
        overflowSpacing: 8,
        children: [
          ...leading,
          TextButton(
            onPressed: cancelEnabled
                ? onCancel ?? () => Navigator.of(context).pop()
                : null,
            child: Text(cancelLabel ?? context.l10n.common_cancel),
          ),
          if (primary != null) primary,
        ],
      ),
    );
  }
}
