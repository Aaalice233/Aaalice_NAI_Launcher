import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/localization_extension.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../providers/online_gallery_provider.dart';
import 'common/app_toast.dart';
import 'common/floating_label_input.dart';

class GelbooruCredentialsDialog extends ConsumerStatefulWidget {
  const GelbooruCredentialsDialog({super.key});

  @override
  ConsumerState<GelbooruCredentialsDialog> createState() =>
      _GelbooruCredentialsDialogState();
}

class _GelbooruCredentialsDialogState
    extends ConsumerState<GelbooruCredentialsDialog> {
  static final Uri _accountSettingsUri = Uri.parse(
    'https://gelbooru.com/index.php?page=account&s=options',
  );

  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final notifier = ref.read(gelbooruAuthProvider.notifier);
      await notifier.ensureInitialized();
      if (!mounted) return;
      final credentials = ref.read(gelbooruAuthProvider).credentials;
      if (credentials != null) {
        _userIdController.text = credentials.userId.toString();
        _apiKeyController.text = credentials.apiKey;
      }
      setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await ref
        .read(gelbooruAuthProvider.notifier)
        .configure(_userIdController.text, _apiKeyController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final savedMessage = context.l10n.gelbooru_saved;
    final galleryNotifier = ref.read(onlineGalleryNotifierProvider.notifier);
    galleryNotifier.invalidateGelbooruFavorites();
    Navigator.of(context).pop();
    AppToast.successOnOverlay(overlay, savedMessage);
    await galleryNotifier.refresh();
  }

  Future<void> _removeCredentials() async {
    setState(() => _isLoading = true);
    await ref.read(gelbooruAuthProvider.notifier).logout();
    if (!mounted) return;
    final galleryNotifier = ref.read(onlineGalleryNotifierProvider.notifier);
    galleryNotifier.invalidateGelbooruFavorites();
    Navigator.of(context).pop();
    await galleryNotifier.refresh();
  }

  String _errorText(GelbooruAuthError error) {
    switch (error) {
      case GelbooruAuthError.invalidInput:
        return context.l10n.gelbooru_invalidInput;
      case GelbooruAuthError.invalidCredentials:
        return context.l10n.gelbooru_invalidCredentials;
      case GelbooruAuthError.rateLimited:
        return context.l10n.gelbooru_rateLimited;
      case GelbooruAuthError.timeout:
        return context.l10n.gelbooru_timeout;
      case GelbooruAuthError.server:
        return context.l10n.gelbooru_serverError;
      case GelbooruAuthError.network:
        return context.l10n.gelbooru_networkError;
      case GelbooruAuthError.malformedResponse:
        return context.l10n.gelbooru_malformedResponse;
      case GelbooruAuthError.storage:
        return context.l10n.gelbooru_storageError;
      case GelbooruAuthError.unknown:
        return context.l10n.gelbooru_unknownError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(gelbooruAuthProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.key_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.gelbooru_configureTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.gelbooru_configureHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FloatingLabelInput(
                  label: context.l10n.gelbooru_userId,
                  controller: _userIdController,
                  hintText: context.l10n.gelbooru_userIdHint,
                  prefixIcon: Icons.person_outline,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !_isLoading,
                  required: true,
                  validator: (value) {
                    final userId = int.tryParse(value?.trim() ?? '');
                    if (userId == null || userId <= 0) {
                      return context.l10n.gelbooru_userIdRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FloatingLabelInput(
                  label: 'API Key',
                  controller: _apiKeyController,
                  hintText: context.l10n.gelbooru_apiKeyHint,
                  prefixIcon: Icons.key_outlined,
                  obscureText: _obscureApiKey,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  enabled: !_isLoading,
                  required: true,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureApiKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () =>
                              setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.gelbooru_apiKeyRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => launchUrl(
                          _accountSettingsUri,
                          mode: LaunchMode.externalApplication,
                        ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(context.l10n.gelbooru_openAccountSettings),
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorText(authState.error!),
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 12,
                  overflowSpacing: 8,
                  children: [
                    if (authState.isConfigured)
                      TextButton(
                        onPressed: _isLoading ? null : _removeCredentials,
                        child: Text(context.l10n.gelbooru_removeCredentials),
                      ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_cancel),
                    ),
                    FilledButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.l10n.gelbooru_save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
