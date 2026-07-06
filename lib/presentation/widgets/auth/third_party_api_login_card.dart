import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/nai_api_endpoint.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../common/floating_label_input.dart';

/// 第三方 NAI-compatible API 登录卡片。
class ThirdPartyApiLoginCard extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const ThirdPartyApiLoginCard({super.key, this.onLoginSuccess});

  @override
  ConsumerState<ThirdPartyApiLoginCard> createState() =>
      _ThirdPartyApiLoginCardState();
}

class _ThirdPartyApiLoginCardState
    extends ConsumerState<ThirdPartyApiLoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _mainApiController = TextEditingController();
  final _imageApiController = TextEditingController();
  final _tokenController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    ref.read(authNotifierProvider.notifier).clearError(delayMs: 0);
  }

  @override
  void dispose() {
    _mainApiController.dispose();
    _imageApiController.dispose();
    _tokenController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FloatingLabelInput(
            label: l10n.auth_thirdPartyApiSite,
            controller: _mainApiController,
            hintText: 'https://example.com/api',
            prefixIcon: Icons.public_outlined,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            required: true,
            validator: (value) => _validateMainApiUrl(value),
          ),
          const SizedBox(height: 16),
          FloatingLabelInput(
            label: l10n.auth_imageApiSiteOptional,
            controller: _imageApiController,
            hintText: l10n.auth_imageApiSiteHint,
            prefixIcon: Icons.image_outlined,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            validator: (value) => _validateImageApiUrl(value),
          ),
          const SizedBox(height: 16),
          FloatingLabelInput(
            label: l10n.settings_nickname,
            controller: _nicknameController,
            hintText: l10n.auth_thirdPartyNicknameHint,
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            required: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.auth_nicknameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FloatingLabelInput(
            label: 'API Token',
            controller: _tokenController,
            hintText: l10n.auth_thirdPartyTokenHint,
            prefixIcon: Icons.vpn_key_outlined,
            obscureText: _obscureToken,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            required: true,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.paste, size: 20),
                  tooltip: context.l10n.common_paste,
                  onPressed: _pasteFromClipboard,
                  splashRadius: 20,
                ),
                IconButton(
                  icon: Icon(
                    _obscureToken
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscureToken = !_obscureToken);
                  },
                  splashRadius: 20,
                ),
              ],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.auth_tokenRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            l10n.auth_thirdPartyCompatibilityHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: authState.isLoading ? null : _handleLogin,
            icon: authState.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login),
            label: Text(context.l10n.auth_validateAndLogin),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (authState.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getErrorMessage(authState.errorCode),
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _validateMainApiUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.auth_thirdPartyApiSiteRequired;
    }

    try {
      NaiApiEndpointConfig.fromInput(
        mainBaseUrl: value,
        imageBaseUrl: _imageApiController.text,
      );
      return null;
    } on ArgumentError catch (e) {
      return e.message.toString();
    }
  }

  String? _validateImageApiUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      NaiApiEndpointConfig.fromInput(
        mainBaseUrl: _mainApiController.text,
        imageBaseUrl: value,
      );
      return null;
    } on ArgumentError catch (e) {
      return e.message.toString();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _tokenController.text = data!.text!.trim();
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final endpoint = NaiApiEndpointConfig.fromInput(
      mainBaseUrl: _mainApiController.text,
      imageBaseUrl: _imageApiController.text,
    );
    final token = _tokenController.text.trim();
    final nickname = _nicknameController.text.trim();

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final accountNotifier = ref.read(accountManagerNotifierProvider.notifier);

    final success = await authNotifier.loginWithThirdPartyToken(
      token,
      apiEndpoint: endpoint,
      displayName: nickname,
    );

    if (!success) return;

    final account = await accountNotifier.addAccount(
      identifier: endpoint.mainBaseUrl,
      token: token,
      nickname: nickname,
      setAsDefault: true,
      apiEndpoint: endpoint,
    );

    await authNotifier.loginWithThirdPartyToken(
      token,
      apiEndpoint: endpoint,
      accountId: account.id,
      displayName: account.displayName,
    );

    if (mounted) {
      widget.onLoginSuccess?.call();
    }
  }

  String _getErrorMessage(AuthErrorCode? errorCode) {
    return switch (errorCode) {
      AuthErrorCode.networkTimeout => context.l10n.auth_error_networkTimeout,
      AuthErrorCode.networkError => context.l10n.auth_error_networkError,
      AuthErrorCode.authFailed => context.l10n.auth_error_authFailed,
      AuthErrorCode.tokenInvalid => context.l10n.auth_tokenInvalid,
      AuthErrorCode.credentialsLoginUnavailable =>
        context.l10n.auth_error_credentialsLoginUnavailable,
      AuthErrorCode.serverError => context.l10n.auth_error_serverError,
      AuthErrorCode.unknown || null => context.l10n.auth_error_unknown,
    };
  }
}
