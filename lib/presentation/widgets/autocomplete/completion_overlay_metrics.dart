import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';

const double autocompleteCandidateExtent = 35;

double effectiveAutocompleteCandidateExtent(BuildContext context) {
  final minimum = context.interactionPolicy.touchAvailable
      ? context.interactionPolicy.minimumControlExtent
      : autocompleteCandidateExtent;
  final scaledFontSize = MediaQuery.textScalerOf(context).scale(13);
  final scaleFactor = scaledFontSize / 13;
  final scaledContentHeight = scaleFactor > 1.3
      ? scaledFontSize * 2.4 + 18
      : scaledFontSize * 1.35 + 16;
  return scaledContentHeight > minimum ? scaledContentHeight : minimum;
}
