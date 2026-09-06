import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/dlss_provider.dart';
import '../../../providers/generation/dlss_upscale_task_provider.dart';
import '../../dlss/dlss_parameter_slider.dart';

class Img2ImgDlssUpscaleControls extends ConsumerWidget {
  const Img2ImgDlssUpscaleControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlss = ref.watch(dlssProvider);
    final task = ref.watch(dlssUpscaleTaskProvider);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.dlss_srHint),
        DlssParameterSlider(
          label: l10n.dlss_scale,
          description: l10n.dlss_srScaleHint,
          value: dlss.options.scale,
          minimum: 1,
          maximum: 16384,
          onChanged: task.running
              ? null
              : (value) => dlss.setOptions(dlss.options.copyWith(scale: value)),
        ),
        if (!dlss.enabled) Text(l10n.dlss_srUnavailable),
        if (task.running) ...[
          const LinearProgressIndicator(),
          TextButton(
            onPressed: ref.read(dlssUpscaleTaskProvider.notifier).cancel,
            child: Text(l10n.common_cancel),
          ),
        ],
        if (task.error != null)
          Text(
            '${task.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
