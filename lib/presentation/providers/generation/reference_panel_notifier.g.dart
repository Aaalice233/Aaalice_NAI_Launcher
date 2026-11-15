// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_panel_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 引用面板 UI 状态

@ProviderFor(ReferencePanelNotifier)
final referencePanelNotifierProvider = ReferencePanelNotifierProvider._();

/// 引用面板 UI 状态
final class ReferencePanelNotifierProvider
    extends $NotifierProvider<ReferencePanelNotifier, ReferencePanelState> {
  /// 引用面板 UI 状态
  ReferencePanelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referencePanelNotifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referencePanelNotifierHash();

  @$internal
  @override
  ReferencePanelNotifier create() => ReferencePanelNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReferencePanelState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReferencePanelState>(value),
    );
  }
}

String _$referencePanelNotifierHash() =>
    r'745b25314f9ffcfd1a8ecf7e11eef317c7990a69';

/// 引用面板 UI 状态

abstract class _$ReferencePanelNotifier extends $Notifier<ReferencePanelState> {
  ReferencePanelState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReferencePanelState, ReferencePanelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReferencePanelState, ReferencePanelState>,
              ReferencePanelState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
