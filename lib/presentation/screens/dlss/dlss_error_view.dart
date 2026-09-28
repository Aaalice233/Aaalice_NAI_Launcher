import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_environment_service.dart';
import '../../../data/services/dlss/dlss_worker.dart';
import 'dlss_environment_card.dart';

String dlssErrorLabel(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is DlssEnvironmentException) {
    return dlssAvailabilityLabel(l10n, error.availability);
  }
  if (error is DlssCancelled) return l10n.dlss_cancelled;
  if (error is DioException) {
    return CancelToken.isCancel(error)
        ? l10n.dlss_operationCancelled
        : l10n.dlss_downloadFailed;
  }
  if (error is TimeoutException) return l10n.dlss_timeout;
  if (error is DlssWorkerFailure && error.resourceLimited) {
    return l10n.dlss_outOfMemory;
  }
  return l10n.dlss_operationFailed;
}

class DlssErrorView extends StatelessWidget {
  const DlssErrorView({super.key, required this.error, this.summary});
  final Object error;
  final String? summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        summary ?? dlssErrorLabel(context, error),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(context.l10n.dlss_diagnostics),
        children: [SelectableText(error.toString())],
      ),
    ],
  );
}
