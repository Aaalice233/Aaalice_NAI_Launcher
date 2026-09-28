import 'dart:async';

import 'package:flutter/material.dart';

import 'image_card_action.dart';
import 'image_card_action_dispatch.dart';
import 'image_card_action_region.dart';

/// Reference forms keep their inline controls while sharing action execution
/// and context-menu semantics with image tiles.
class ImageCardInlineActions extends StatelessWidget {
  const ImageCardInlineActions({
    super.key,
    required this.actions,
    this.direction = Axis.horizontal,
  });
  final List<ImageCardAction> actions;
  final Axis direction;

  @override
  Widget build(BuildContext context) => ImageCardActionRegion(
    actions: actions,
    builder: (context, bound) => Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in bound.where((action) => action.visible))
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              key: action.key,
              tooltip: action.label,
              onPressed: action.canInvoke
                  ? () => unawaited(dispatchImageCardAction(context, action))
                  : null,
              icon: action.isLoading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: MediaQuery.disableAnimationsOf(context)
                            ? .72
                            : null,
                      ),
                    )
                  : Icon(action.icon, size: 18, color: action.iconColor),
            ),
          ),
      ],
    ),
  );
}
