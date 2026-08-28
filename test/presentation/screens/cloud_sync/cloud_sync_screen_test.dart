import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_section.dart';
import 'package:nai_launcher/presentation/screens/cloud_sync/cloud_sync_initial_choice.dart';

void main() {
  testWidgets('未连接布局在五档宽度均无 overflow', (tester) async {
    for (final width in [390.0, 700.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      expect(find.text('同步与备份'), findsWidgets);
      expect(find.text('尚未连接'), findsOneWidget);
      expect(find.text('WebDAV'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('继续真实测试'),
        120,
        scrollable: _pageScrollable,
      );
      expect(find.text('继续真实测试'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('分步连接覆盖真实测试、范围、加密、远端检测与首次操作', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final port = _FakePort();
    await tester.pumpWidget(_subject(port: port));
    await tester.pumpAndSettle();

    final insecureSwitch = find.byKey(
      const ValueKey('cloud-sync-allow-insecure-http'),
    );
    expect(tester.widget<SwitchListTile>(insecureSwitch).value, isFalse);
    expect(find.text('允许不安全的 HTTP'), findsOneWidget);
    expect(find.textContaining('明文传输 WebDAV 凭据'), findsOneWidget);
    await tester.scrollUntilVisible(
      insecureSwitch,
      120,
      scrollable: _pageScrollable,
    );
    await tester.tap(insecureSwitch);
    await tester.pumpAndSettle();

    final passwordField = _fieldWithLabel('密码');
    await tester.enterText(passwordField, 'webdav-secret');
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
    await _tapText(tester, '继续真实测试');

    expect(find.text('webdav-secret'), findsNothing);
    await _tapText(tester, '运行真实测试');
    expect(find.text('连接验证成功'), findsOneWidget);
    expect(find.text('服务商限额：2 GiB'), findsOneWidget);
    expect(find.text('历史快照'), findsOneWidget);
    expect(find.text('仅删除云端 namespace'), findsOneWidget);
    expect(find.text('provider warning'), findsOneWidget);
    await _tapText(tester, '继续选择数据范围');

    expect(find.text('选择同步数据'), findsOneWidget);
    expect(find.text('大二进制文件'), findsOneWidget);
    await _tapText(tester, '继续加密设置');

    await _tapText(tester, '检测远端', last: true);
    expect(port.remoteDetected, isTrue);

    await tester.enterText(_fieldWithLabel('加密密码'), 'encryption-secret');
    await tester.enterText(_fieldWithLabel('确认密码'), 'encryption-secret');
    expect(
      tester.widget<TextField>(_fieldWithLabel('加密密码')).obscureText,
      isTrue,
    );
    await _tapText(tester, '生成一次性恢复密钥');
    expect(find.text('recovery-key-once'), findsOneWidget);
    await _tapText(tester, '我已保存并核对一次性恢复密钥');
    await _tapText(tester, '首次同步', last: true);

    expect(find.text('encryption-secret'), findsNothing);
    expect(find.text('recovery-key-once'), findsNothing);
    expect(find.text('选择首次同步方式'), findsOneWidget);

    await _tapText(tester, '预览并合并（推荐）');
    await _tapText(tester, '连接并继续');
    expect(port.request, isNotNull);
    expect(port.request!.initialAction, CloudSyncInitialAction.mergePreview);
    expect(port.request!.encryptionPassword, 'encryption-secret');
    expect(port.request!.connection.allowInsecureHttp, isTrue);
    expect(port.request!.contentSelection.includeAgentSystemPrompt, isTrue);
    expect(port.request!.contentSelection.includeSkills, isFalse);
    expect(find.text('webdav-secret'), findsNothing);
    expect(find.text('encryption-secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GitHub token 输入始终使用敏感字段且不在后续阶段回显', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject(port: _FakePort()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    final tokenField = _fieldWithLabel('GitHub Token');
    expect(tester.widget<TextField>(tokenField).obscureText, isTrue);
    await tester.enterText(tokenField, 'github-sensitive-token');
    await _tapText(tester, '继续真实测试');

    expect(find.text('github-sensitive-token'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已连接状态展示降级能力、完整进度、历史与待处理冲突', (tester) async {
    final state = _connectedState();
    final port = _FakePort();
    for (final width in [390.0, 700.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_subject(state: state, port: port));
      await tester.pumpAndSettle();

      expect(find.text('仅手动云备份'), findsOneWidget);
      expect(find.text('GitHub 历史保留'), findsOneWidget);
      expect(find.text('远端维护提示'), findsOneWidget);
      expect(find.text('cleanup delayed'), findsOneWidget);
      expect(find.text('需处理冲突'), findsWidgets);
      expect(find.text('已完全同步'), findsNothing);
      expect(find.text('settings.json'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('暂停'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('历史快照'), findsOneWidget);
      expect(find.text('大二进制冲突默认保留两个副本。'), findsOneWidget);
      expect(find.text('两者都保留'), findsWidgets);
      expect(find.text('修改加密密码'), findsOneWidget);
      expect(find.textContaining('只重新封装加密密钥'), findsOneWidget);
      expect(find.text('仅删除云端 namespace'), findsOneWidget);
      expect(find.text('断开此设备'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.pumpWidget(
      _subject(
        state: _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ),
        port: port,
      ),
    );
    await tester.pumpAndSettle();
    final bulkRemote = find.byKey(const ValueKey('cloud-sync-bulk-remote'));
    await tester.scrollUntilVisible(
      bulkRemote,
      180,
      scrollable: _pageScrollable,
    );
    await tester.tap(bulkRemote);
    await tester.pump();
    expect(port.bulkChoice, CloudSyncConflictChoice.remote);
    final keepBoth = find.byKey(
      const ValueKey('cloud-sync-conflict-image-1-keepBoth'),
    );
    await tester.scrollUntilVisible(keepBoth, 180, scrollable: _pageScrollable);
    await tester.tap(keepBoth);
    await tester.pump();
    expect(port.conflictChoice, CloudSyncConflictChoice.keepBoth);

    await tester.pumpWidget(
      _subject(
        state: _connectedState(activityStatus: CloudSyncActivityStatus.paused),
        port: port,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('继续'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('合并与恢复预览展示真实摘要且必须确认后应用', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final port = _FakePort();
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          clearProgress: true,
          conflicts: const [],
          pendingPreview: const CloudSyncPreviewView(
            title: 'initial',
            changes: [
              CloudSyncChangeSummary(
                kind: CloudSyncDataKind.prompts,
                added: 2,
                modified: 3,
                deleted: 1,
              ),
            ],
          ),
          pendingFfdkjInstall: true,
        );
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    expect(find.text('首次合并预览'), findsOneWidget);
    expect(find.text('新增 2 · 修改 3 · 删除 1'), findsOneWidget);
    expect(find.text('已完全同步'), findsNothing);
    expect(find.textContaining('不包含或传输 tag.sqlite'), findsOneWidget);
    final restorePreview = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '预览恢复'),
    );
    expect(restorePreview.onPressed, isNull);
    final confirm = find.byKey(const ValueKey('cloud-sync-confirm-preview'));
    await tester.scrollUntilVisible(confirm, 180, scrollable: _pageScrollable);
    await tester.tap(confirm);
    await tester.pump();
    expect(port.previewApplied, isTrue);

    await _tapText(tester, '暂不安装并清除提示');
    expect(port.ffdkjInstallChoice, isFalse);
  });

  testWidgets('仅手动备份模式隐藏恢复并禁用冲突应用', (tester) async {
    await tester.pumpWidget(
      _subject(
        state: _connectedState(activityStatus: CloudSyncActivityStatus.idle),
        port: _FakePort(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('预览恢复'), findsNothing);
    final bulk = tester.widget<FilledButton>(
      find.byKey(const ValueKey('cloud-sync-bulk-local')),
    );
    expect(bulk.onPressed, isNull);
  });

  testWidgets('setup 在仅手动备份模式只提供上传', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CloudSyncInitialChoice(
            value: CloudSyncInitialAction.upload,
            manualBackupOnly: true,
            busy: false,
            onChanged: (_) {},
            onConnect: () {},
          ),
        ),
      ),
    );
    expect(find.text('上传本设备数据'), findsOneWidget);
    expect(find.text('下载远端数据'), findsNothing);
    expect(find.text('预览并合并（推荐）'), findsNothing);
  });

  testWidgets('新恢复密钥在明确确认前持续显示且不会写入活动日志', (tester) async {
    final port = _FakePort();
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          conflicts: const [],
          pendingRecoveryKey: 'new-recovery-key-once',
          logs: const [],
          clearProgress: true,
        );
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    expect(find.text('新的恢复密钥已生效'), findsWidgets);
    expect(find.text('new-recovery-key-once'), findsOneWidget);
    expect(
      find.textContaining('new-recovery-key-once', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('暂无同步活动。'), findsOneWidget);
    final saved = find.text('我已保存新密钥');
    await tester.scrollUntilVisible(saved, 180, scrollable: _pageScrollable);
    await tester.tap(saved);
    await tester.pumpAndSettle();
    expect(find.textContaining('确认已将新恢复密钥完整保存'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(port.recoveryKeyConfirmed, isTrue);
  });
}

Finder _fieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _tapText(
  WidgetTester tester,
  String text, {
  bool last = false,
}) async {
  final finder = find.text(text);
  final target = finder.at(last ? finder.evaluate().length - 1 : 0);
  await tester.scrollUntilVisible(target, 180, scrollable: _pageScrollable);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder get _pageScrollable => find
    .descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    )
    .at(0);

Widget _subject({CloudSyncUiState? state, CloudSyncUiPort? port}) {
  return ProviderScope(
    overrides: [
      if (state != null) cloudSyncUiStateProvider.overrideWithValue(state),
      if (port != null) cloudSyncUiPortProvider.overrideWithValue(port),
      localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(initialSection: SettingsSection.cloudSync),
    ),
  );
}

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

CloudSyncUiState _connectedState({
  CloudSyncActivityStatus activityStatus = CloudSyncActivityStatus.syncing,
  CloudSyncCapabilityMode capabilityMode =
      CloudSyncCapabilityMode.manualBackupOnly,
}) => CloudSyncUiState(
  connectionStatus: CloudSyncConnectionStatus.connected,
  activityStatus: activityStatus,
  backend: CloudSyncBackendKind.github,
  deviceName: 'Android tablet',
  lastSync: DateTime.utc(2026, 3, 12, 10, 30),
  remoteRevision: 'rev-42',
  capabilityMode: capabilityMode,
  maintenanceWarning: 'cleanup delayed',
  progress: const CloudSyncProgressView(
    stage: 'Uploading',
    objectName: 'settings.json',
    completedBytes: 1024,
    totalBytes: 4096,
    completedObjects: 2,
    totalObjects: 5,
  ),
  logs: [
    CloudSyncLogEntry(
      time: DateTime.utc(2026, 3, 12, 10, 30),
      message: 'Remote head loaded',
    ),
  ],
  snapshots: [
    CloudSyncSnapshotView(
      id: 'snapshot-41',
      createdAt: DateTime.utc(2026, 3, 11),
      summary: 'Before tablet sync',
    ),
  ],
  conflicts: const [
    CloudSyncConflictView(
      id: 'prompt-1',
      kind: CloudSyncDataKind.prompts,
      title: 'Portrait preset',
      baseSummary: '12 tags',
      localSummary: '14 tags',
      remoteSummary: '13 tags',
    ),
    CloudSyncConflictView(
      id: 'image-1',
      kind: CloudSyncDataKind.largeBinary,
      title: 'reference.png',
      baseSummary: '8 MiB',
      localSummary: '9 MiB',
      remoteSummary: '10 MiB',
    ),
  ],
);

class _FakePort extends CloudSyncUiPortAdapter {
  CloudSyncConnectRequest? request;
  bool remoteDetected = false;
  CloudSyncConflictChoice? conflictChoice;
  CloudSyncConflictChoice? bulkChoice;
  bool previewApplied = false;
  bool? ffdkjInstallChoice;
  bool recoveryKeyConfirmed = false;

  @override
  Future<void> applyPendingPreview() async => previewApplied = true;

  @override
  Future<void> respondToFfdkjInstallIntent({required bool install}) async {
    ffdkjInstallChoice = install;
  }

  @override
  Future<void> confirmRecoveryKeySaved() async {
    recoveryKeyConfirmed = true;
  }

  @override
  Future<String> createRecoveryKey(String password) async =>
      'recovery-key-once';

  @override
  Future<void> recoverKeyEnvelope(
    String recoveryKey,
    String newPassword,
  ) async {}

  @override
  Future<CloudSyncCapabilityResult> testConnection(
    CloudSyncConnectionDraft connection,
  ) async => const CloudSyncCapabilityResult(
    succeeded: true,
    mode: CloudSyncCapabilityMode.bidirectional,
    message: 'Conditional writes and history are available.',
    supportsHistory: true,
    supportsDelete: true,
    warnings: ['provider warning'],
    limit: '2 GiB',
  );

  @override
  Future<void> detectRemote(CloudSyncConnectionDraft connection) async {
    remoteDetected = true;
  }

  @override
  Future<void> connect(CloudSyncConnectRequest request) async {
    this.request = request;
  }

  @override
  Future<void> resolveConflict(
    String conflictId,
    CloudSyncConflictChoice choice,
  ) async {
    conflictChoice = choice;
  }

  @override
  Future<void> resolveAllConflicts(CloudSyncConflictChoice choice) async {
    bulkChoice = choice;
  }
}
