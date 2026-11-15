import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/prompt_assistant_service.dart';

/// 各服务商最近一次拉到的模型 ID；只在本次运行内保留，用来标出接口已不再列出的模型。
final providerRemoteModelsProvider =
    NotifierProvider<ProviderRemoteModelsNotifier, Map<String, List<String>>>(
      ProviderRemoteModelsNotifier.new,
    );

class ProviderRemoteModelsNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() => const {};

  Future<List<String>> fetch(String providerId) async {
    final names = await ref
        .read(promptAssistantServiceProvider)
        .fetchAvailableModels(providerId);
    final unique = <String>{
      for (final name in names)
        if (name.trim().isNotEmpty) name.trim(),
    }.toList();
    if (ref.mounted) {
      state = {...state, providerId: unique};
    }
    return unique;
  }

  /// 地址或密钥变化后旧列表不再代表这个服务商。
  void forget(String providerId) {
    if (!ref.mounted || !state.containsKey(providerId)) return;
    state = {...state}..remove(providerId);
  }
}
