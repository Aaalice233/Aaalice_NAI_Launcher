import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/config/auth_feature_flags.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../providers/auth_mode_provider.dart';

/// 登录模式切换组件
class AuthModeSwitcher extends ConsumerWidget {
  const AuthModeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(authModeProvider);
    const credentialsEnabled = AuthFeatureFlags.credentialsLoginEnabled;
    final effectiveMode =
        !credentialsEnabled && currentMode == AuthMode.credentials
        ? AuthMode.token
        : currentMode;

    return Row(
      key: const Key('auth_mode_switcher'),
      children: [
        Expanded(
          child: _buildModeButton(
            key: const Key('auth_mode_token'),
            context: context,
            label: context.l10n.auth_tokenLoginRecommended,
            icon: Icons.key_outlined,
            isSelected: effectiveMode == AuthMode.token,
            onTap: () {
              ref
                  .read(authModeNotifierProvider.notifier)
                  .switchMode(AuthMode.token);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeButton(
            key: const Key('auth_mode_credentials'),
            context: context,
            label: context.l10n.auth_credentialsLogin,
            icon: Icons.email_outlined,
            isSelected: effectiveMode == AuthMode.credentials,
            enabled: credentialsEnabled,
            disabledTooltip: context.l10n.auth_credentialsLoginUnavailable,
            onTap: () {
              ref
                  .read(authModeNotifierProvider.notifier)
                  .switchMode(AuthMode.credentials);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeButton(
            key: const Key('auth_mode_third_party'),
            context: context,
            label: context.l10n.auth_thirdPartyLogin,
            icon: Icons.public_outlined,
            isSelected: effectiveMode == AuthMode.thirdParty,
            onTap: () {
              ref
                  .read(authModeNotifierProvider.notifier)
                  .switchMode(AuthMode.thirdParty);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    Key? key,
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool enabled = true,
    String? disabledTooltip,
  }) {
    final theme = Theme.of(context);
    final foregroundColor = enabled
        ? (isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant)
        : theme.disabledColor;

    final button = InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled && isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: enabled && isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foregroundColor,
                    height: 1.1,
                    fontWeight: enabled && isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (enabled || disabledTooltip == null) {
      return button;
    }
    return Tooltip(message: disabledTooltip, child: button);
  }
}
