import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/proxy_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/settings/proxy_settings.dart';
import '../../../providers/proxy_settings_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_input.dart';
import '../widgets/settings_card.dart';

/// 网络设置板块
///
/// 包含代理设置：
/// - 启用/禁用代理开关
/// - 自动/手动代理模式选择
/// - 手动代理主机和端口配置
/// - 代理连接测试
class NetworkSettingsSection extends ConsumerStatefulWidget {
  const NetworkSettingsSection({super.key});

  @override
  ConsumerState<NetworkSettingsSection> createState() =>
      NetworkSettingsSectionState();
}

class NetworkSettingsSectionState
    extends ConsumerState<NetworkSettingsSection> {
  bool _isTesting = false;
  String? _testResult;

  // 手动代理输入控制器
  final _hostController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proxySettings = ref.watch(proxySettingsNotifierProvider);
    final detectedProxy = ref.watch(detectedSystemProxyProvider);
    final l10n = context.l10n;

    // 初始化手动代理输入框
    if (_hostController.text.isEmpty && proxySettings.manualHost != null) {
      _hostController.text = proxySettings.manualHost!;
    }
    if (_portController.text.isEmpty && proxySettings.manualPort != null) {
      _portController.text = proxySettings.manualPort.toString();
    }

    return SettingsCard(
      title: '网络',
      icon: Icons.network_check,
      child: Column(
        children: [
          // 启用代理开关
          SwitchListTile(
            secondary: const Icon(Icons.wifi_tethering),
            title: Text(l10n.settings_enableProxy),
            subtitle: Text(
              proxySettings.enabled
                  ? '${l10n.settings_proxyEnabled}: ${proxySettings.effectiveProxyAddress ?? l10n.settings_proxyNotDetected}'
                  : l10n.settings_proxyDisabled,
            ),
            value: proxySettings.enabled,
            onChanged: (value) async {
              await ref
                  .read(proxySettingsNotifierProvider.notifier)
                  .setEnabled(value);
              if (mounted) {
                AppToast.info(
                  // ignore: use_build_context_synchronously
                  context,
                  l10n.settings_proxyRestartHint,
                );
              }
            },
          ),

          // 代理模式选择（仅在启用时显示）
          if (proxySettings.enabled) ...[
            ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: Text(l10n.settings_proxyMode),
              subtitle: Text(
                proxySettings.mode == ProxyMode.auto
                    ? '${l10n.settings_proxyModeAuto} (${detectedProxy ?? l10n.settings_proxyNotDetected})'
                    : l10n.settings_proxyModeManual,
              ),
              trailing: SegmentedButton<ProxyMode>(
                segments: [
                  ButtonSegment(
                    value: ProxyMode.auto,
                    label: Text(l10n.settings_auto),
                  ),
                  ButtonSegment(
                    value: ProxyMode.manual,
                    label: Text(l10n.settings_manual),
                  ),
                ],
                selected: {proxySettings.mode},
                onSelectionChanged: (set) async {
                  await ref
                      .read(proxySettingsNotifierProvider.notifier)
                      .setMode(set.first);
                },
              ),
            ),

            // 手动模式输入框
            if (proxySettings.mode == ProxyMode.manual)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ThemedInput(
                        controller: _hostController,
                        decoration: InputDecoration(
                          labelText: l10n.settings_proxyHost,
                          hintText: '127.0.0.1',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _saveManualProxy(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: ThemedInput(
                        controller: _portController,
                        decoration: InputDecoration(
                          labelText: l10n.settings_proxyPort,
                          hintText: '7890',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => _saveManualProxy(),
                      ),
                    ),
                  ],
                ),
              ),

            // 测试连接按钮
            ListTile(
              leading: const Icon(Icons.network_check),
              title: Text(l10n.settings_testConnection),
              subtitle: Text(_testResult ?? l10n.settings_testConnectionHint),
              trailing: _isTesting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _testProxyConnection,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  /// 保存手动代理设置
  void _saveManualProxy() {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();

    if (host.isNotEmpty && portText.isNotEmpty) {
      final port = int.tryParse(portText);
      if (port != null && port > 0 && port <= 65535) {
        ref.read(proxySettingsNotifierProvider.notifier).setManualProxy(
              host,
              port,
            );
      }
    }
  }

  /// 测试代理连接
  Future<void> _testProxyConnection() async {
    final proxySettings = ref.read(proxySettingsNotifierProvider);
    final proxyAddress = proxySettings.effectiveProxyAddress;
    final l10n = context.l10n;

    if (proxyAddress == null || proxyAddress.isEmpty) {
      setState(() {
        _testResult = l10n.settings_proxyNotDetected;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final result = await ProxyService.testProxyConnection(proxyAddress);

      if (mounted) {
        setState(() {
          _isTesting = false;
          if (result.success) {
            _testResult = l10n.settings_testSuccess(result.latencyMs ?? 0);
          } else {
            _testResult =
                l10n.settings_testFailed(result.errorMessage ?? 'Unknown');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = l10n.settings_testFailed(e.toString());
        });
      }
    }
  }
}
