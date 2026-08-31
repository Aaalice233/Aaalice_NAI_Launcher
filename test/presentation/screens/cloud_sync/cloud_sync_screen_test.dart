import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_section.dart';

void main() {
  testWidgets('未连接布局在五档宽度均无 overflow', (tester) async {
    for (final width in [390.0, 700.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      expect(find.text('备份与恢复'), findsWidgets);
      expect(find.text('尚未连接'), findsOneWidget);
      expect(find.text('WebDAV'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Google Drive'), findsOneWidget);
      expect(find.text('OneDrive'), findsOneWidget);
      expect(find.text('保存连接'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('WebDAV 只填写服务商字段即可保存连接', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final port = _FakePort();
    await tester.pumpWidget(_subject(port: port));
    await tester.pumpAndSettle();

    final urlField = _fieldWithLabel('WebDAV 地址');
    final usernameField = _fieldWithLabel('用户名');
    await tester.enterText(urlField, 'https://dav.test');
    await tester.enterText(usernameField, 'user');
    final passwordField = _fieldWithLabel('密码');
    await tester.enterText(passwordField, 'webdav-secret');
    expect(
      tester.widget<TextField>(urlField).controller!.text,
      'https://dav.test',
    );
    expect(tester.widget<TextField>(usernameField).controller!.text, 'user');
    expect(
      tester.widget<TextField>(passwordField).controller!.text,
      'webdav-secret',
    );
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
    expect(find.text('选择要保存的内容'), findsOneWidget);
    expect(find.text('图片与其他大文件'), findsOneWidget);
    expect(find.textContaining('快照'), findsNothing);
    expect(find.textContaining('后端'), findsNothing);
    expect(find.text('设置加密密码'), findsNothing);
    expect(find.text('生成一次性恢复密钥'), findsNothing);
    final save = find.byKey(const ValueKey('cloud-sync-save-connection'));
    await tester.scrollUntilVisible(save, 180, scrollable: _pageScrollable);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(port.request, isNotNull);
    expect(port.request!.dataKinds, {
      CloudSyncDataKind.settings,
      CloudSyncDataKind.prompts,
      CloudSyncDataKind.galleries,
    });
    expect(port.request!.contentSelection.includeAgentSystemPrompt, isTrue);
    expect(port.request!.contentSelection.includeSkills, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GitHub token 始终使用敏感字段并可一键连接', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject(port: _FakePort()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    final tokenField = _fieldWithLabel('GitHub 访问令牌');
    expect(tester.widget<TextField>(tokenField).obscureText, isTrue);
    await tester.enterText(tokenField, 'github-sensitive-token');
    await tester.enterText(_fieldWithLabel('GitHub 用户或组织'), 'alice');
    await tester.enterText(_fieldWithLabel('仓库'), 'backup');
    final save = find.byKey(const ValueKey('cloud-sync-save-connection'));
    await tester.scrollUntilVisible(save, 180, scrollable: _pageScrollable);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('已连接状态展示降级能力、完整进度、历史与待处理冲突', (tester) async {
    final state = _connectedState();
    final port = _FakePort();
    for (final width in [390.0, 700.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_subject(state: state, port: port));
      await tester.pumpAndSettle();

      expect(find.text('只支持手动推送与拉取'), findsOneWidget);
      expect(find.text('GitHub 空间说明'), findsOneWidget);
      expect(find.text('需要注意'), findsOneWidget);
      expect(find.text('云端空间暂时无法自动整理。现有备份不受影响，稍后会自动重试。'), findsOneWidget);
      expect(find.text('cleanup delayed'), findsNothing);
      expect(find.text('请选择要保留的内容'), findsWidgets);
      expect(find.text('已连接'), findsNothing);
      expect(find.text('settings.json'), findsNothing);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('正在上传'), findsOneWidget);
      expect(find.text('暂停'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('以前的备份'), findsOneWidget);
      expect(find.text('包含 12 项内容'), findsOneWidget);
      expect(find.text('大文件会默认保留两个版本，避免丢失。'), findsOneWidget);
      expect(find.text('两者都保留'), findsWidgets);
      expect(find.text('修改加密密码'), findsNothing);
      expect(find.text('删除云端备份'), findsOneWidget);
      expect(find.text('断开连接'), findsOneWidget);
      expect(find.textContaining('namespace'), findsNothing);
      expect(find.textContaining('revision'), findsNothing);
      expect(find.textContaining('Base'), findsNothing);
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

    expect(find.text('合并内容确认'), findsOneWidget);
    expect(find.text('新增 2 · 修改 3 · 删除 1'), findsOneWidget);
    expect(find.text('已连接'), findsNothing);
    expect(find.textContaining('词库文件不会通过云端传输'), findsOneWidget);
    final restorePreview = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '查看并恢复'),
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

  testWidgets('仅手动备份模式允许显式拉取但禁用历史恢复和合并', (tester) async {
    await tester.pumpWidget(
      _subject(
        state: _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
        ).copyWith(remoteExists: true),
        port: _FakePort(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('查看并恢复'), findsNothing);
    final pull = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '从云端拉取'),
    );
    expect(pull.onPressed, isNotNull);
    final bulk = tester.widget<FilledButton>(
      find.byKey(const ValueKey('cloud-sync-bulk-local')),
    );
    expect(bulk.onPressed, isNull);
  });

  testWidgets('存储服务警告会直接显示在已连接页面', (tester) async {
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          capabilityWarnings: const ['当前 GitHub 仓库是公开仓库'],
          clearProgress: true,
        );

    await tester.pumpWidget(_subject(state: state, port: _FakePort()));
    await tester.pumpAndSettle();

    expect(find.text('存储服务提示'), findsOneWidget);
    expect(find.text('当前 GitHub 仓库是公开仓库'), findsOneWidget);
  });

  testWidgets('推送和拉取使用独立按钮并在执行前二次确认方向', (tester) async {
    final port = _FakePort();
    final state = _connectedState(
      activityStatus: CloudSyncActivityStatus.idle,
      capabilityMode: CloudSyncCapabilityMode.bidirectional,
    ).copyWith(remoteExists: true, conflicts: const [], clearProgress: true);
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    await _tapText(tester, '推送到云端');
    expect(find.text('推送本机数据？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    expect(port.pushes, 1);
    expect(port.pulls, 0);

    await _tapText(tester, '从云端拉取');
    expect(find.text('拉取云端数据？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    expect(port.pushes, 1);
    expect(port.pulls, 1);
  });

  testWidgets('云盘恢复密钥阻止同步并可解锁账号隔离快照', (tester) async {
    final port = _FakePort();
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          backend: CloudSyncBackendKind.oneDrive,
          accountId: 'tenant:account',
          accountLabel: 'user@example.test',
          recoveryRequired: true,
          conflicts: const [],
          clearProgress: true,
        );
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    expect(find.text('需要恢复密钥'), findsOneWidget);
    expect(find.text('user@example.test'), findsOneWidget);
    final push = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '推送到云端'),
    );
    expect(push.onPressed, isNull);
    await tester.enterText(_fieldWithLabel('恢复密钥'), 'AA1-recovery');
    await tester.pump();
    final unlock = find.byKey(const ValueKey('cloud-sync-unlock-recovery-key'));
    await tester.scrollUntilVisible(unlock, 180, scrollable: _pageScrollable);
    expect(
      tester.widget<TextField>(_fieldWithLabel('恢复密钥')).controller!.text,
      'AA1-recovery',
    );
    expect(tester.widget<FilledButton>(unlock).onPressed, isNotNull);
    await tester.tap(unlock);
    await tester.pumpAndSettle();
    expect(port.recoveryKey, 'AA1-recovery');
  });

  testWidgets('新云盘恢复密钥必须明确确认保存', (tester) async {
    final port = _FakePort();
    final state =
        _connectedState(
          activityStatus: CloudSyncActivityStatus.idle,
          capabilityMode: CloudSyncCapabilityMode.bidirectional,
        ).copyWith(
          backend: CloudSyncBackendKind.googleDrive,
          accountId: 'google-account',
          accountLabel: 'google@example.test',
          pendingRecoveryKey: 'AA1-new-recovery-key',
          conflicts: const [],
          clearProgress: true,
        );
    await tester.pumpWidget(_subject(state: state, port: port));
    await tester.pumpAndSettle();

    expect(find.text('AA1-new-recovery-key'), findsOneWidget);
    final saved = find.byKey(const ValueKey('cloud-sync-recovery-saved'));
    await tester.scrollUntilVisible(saved, 180, scrollable: _pageScrollable);
    await tester.tap(saved);
    await tester.pump();
    final confirm = find.byKey(
      const ValueKey('cloud-sync-confirm-recovery-key'),
    );
    await tester.scrollUntilVisible(confirm, 180, scrollable: _pageScrollable);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(port.recoveryConfirmed, isTrue);
  });

  testWidgets('网络失败只显示可读提示且不暴露异常类型', (tester) async {
    final port = _FakePort()
      ..syncError = const CloudBackendException(
        CloudBackendErrorKind.network,
        '无法连接服务器，请检查网络、代理和服务地址后重试。',
      );
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

    await _tapText(tester, '推送到云端');
    expect(find.text('推送本机数据？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();

    expect(find.text('操作失败：无法连接服务器，请检查网络、代理和服务地址后重试。'), findsOneWidget);
    expect(find.textContaining('CloudBackendException'), findsNothing);
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
    stage: 'uploading',
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
      objectCount: 12,
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
  Object? syncError;
  var pushes = 0;
  var pulls = 0;
  String? recoveryKey;
  bool recoveryConfirmed = false;

  @override
  Future<void> recoverCloudDriveEncryption(String recoveryKey) async {
    this.recoveryKey = recoveryKey;
  }

  @override
  Future<void> confirmCloudDriveRecoveryKeySaved() async {
    recoveryConfirmed = true;
  }

  @override
  Future<void> pushNow() async {
    pushes++;
    final error = syncError;
    if (error != null) throw error;
  }

  @override
  Future<void> pullNow() async {
    pulls++;
    final error = syncError;
    if (error != null) throw error;
  }

  @override
  Future<void> applyPendingPreview() async => previewApplied = true;

  @override
  Future<void> respondToFfdkjInstallIntent({required bool install}) async {
    ffdkjInstallChoice = install;
  }

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
