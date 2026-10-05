import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/prompt_assistant_service.dart';

/// 各服务商最近一次拉到的模型 ID；只在本次运行内保留，用来标出接口已不再列出的模型。
final providerRemoteModelsProvider =
    StateNotifierProvider<
      ProviderRemoteModelsNotifier,
      Map<String, List<String>>
    >((ref) => ProviderRemoteModelsNotifier(ref));

class ProviderRemoteModelsNotifier
    extends StateNotifier<Map<String, List<String>>> {
  ProviderRemoteModelsNotifier(this._ref) : super(const {});

  final Ref _ref;

  Future<List<String>> fetch(String providerId) async {
    final names = await _ref
        .read(promptAssistantServiceProvider)
        .fetchAvailableModels(providerId);
    final unique = <String>{
      for (final name in names)
        if (name.trim().isNotEmpty) name.trim(),
    }.toList();
    state = {...state, providerId: unique};
    return unique;
  }

  /// 地址或密钥变化后旧列表不再代表这个服务商。
  void forget(String providerId) {
    if (!state.containsKey(providerId)) return;
    state = {...state}..remove(providerId);
  }
}
