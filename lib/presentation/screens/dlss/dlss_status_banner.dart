import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/dlss_provider.dart';
import 'dlss_error_view.dart';

class DlssStatusBanner extends ConsumerWidget {
  const DlssStatusBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlss = ref.watch(dlssProvider);
    if (!dlss.enhancing &&
        dlss.enhancementError == null &&
        dlss.queuedJobs == 0) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dlss.enhancing) ...[
              const LinearProgressIndicator(),
              Text(context.l10n.dlss_running),
            ] else if (dlss.queuedJobs > 0)
              Text('${context.l10n.dlss_queued}: ${dlss.queuedJobs}')
            else
              DlssErrorView(
                error: dlss.enhancementError!,
                summary: context.l10n.dlss_failed,
              ),
          ],
        ),
      ),
    );
  }
}
