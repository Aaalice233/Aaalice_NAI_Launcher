import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import '../../../../data/services/auth_provider.dart';
import '../../../providers/cost_estimate_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/krita/krita_bridge_notifier.dart';
import '../../../utils/asset_protection_guard.dart';
import '../../../widgets/common/app_toast.dart';

/// 带资产保护确认的生成入口（经典布局与官网式布局共用）
Future<void> generateWithProtection(BuildContext context, WidgetRef ref) async {
  final currentParams = ref.read(generationParamsNotifierProvider);
  if (ref.read(generationCooldownProvider).isActive) {
    return;
  }
  if (PlatformCapabilities.current.supportsKritaBridge &&
      ref.read(kritaBridgeNotifierProvider).isBridgeGenerating) {
    AppToast.warning(context, context.l10n.kritaBridge_busyGenerating);
    return;
  }
  if (currentParams.prompt.isEmpty) {
    AppToast.warning(context, context.l10n.generation_pleaseInputPrompt);
    return;
  }
  await submitGenerationWithProtection(context, ref);
}

Future<void> submitGenerationWithProtection(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? closePromptEditor,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final request = readGenerationPageRequest(container);
  var accountChanged = false;
  final account = container.listen(
    authNotifierProvider.select((auth) => auth.accountId),
    (_, __) => accountChanged = true,
  );
  try {
    if (closePromptEditor != null) {
      closePromptEditor();
      await Future<void>.delayed(Duration.zero);
    }
    if (!context.mounted || accountChanged) return;
    final confirmed = await AssetProtectionGuard.confirmHighAnlasCost(
      context: context,
      ref: ref,
      estimateCost: () async {
        final cost = await readSettledEstimatedCost(container, request);
        return accountChanged ? null : cost;
      },
    );
    if (!confirmed || !context.mounted || accountChanged) return;
    final (params, workflow, batchSize) = request;
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    generation.generate(
      params,
      batchSizeOverride: batchSize,
      focusedOverride: workflow.focusedSnapshot,
    );
  } finally {
    account.close();
  }
}
