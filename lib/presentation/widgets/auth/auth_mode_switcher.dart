import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/auth_mode_provider.dart';

/// 登录模式切换组件
class AuthModeSwitcher extends ConsumerWidget {
  const AuthModeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(authModeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildModeButton(
          context: context,
          label: context.l10n.auth_credentialsLogin,
          icon: Icons.email_outlined,
          isSelected: currentMode == AuthMode.credentials,
          onTap: () {
            ref.read(authModeNotifierProvider.notifier).switchMode(AuthMode.credentials);
          },
        ),
        const SizedBox(width: 16),
        _buildModeButton(
          context: context,
          label: context.l10n.auth_tokenLogin,
          icon: Icons.key_outlined,
          isSelected: currentMode == AuthMode.token,
          onTap: () {
            ref.read(authModeNotifierProvider.notifier).switchMode(AuthMode.token);
          },
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primaryContainer 
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isSelected 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
