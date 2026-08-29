import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/crypto_models.dart';
import '../../../core/cloud_sync/models.dart';
import 'cloud_sync_operation_runner.dart';
import 'cloud_sync_ui_provider.dart';

class CloudSyncErrorReporter {
  const CloudSyncErrorReporter({
    required this.readState,
    required this.writeState,
  });

  final CloudSyncStateReader readState;
  final CloudSyncStateWriter writeState;

  void record(Object error, {bool resetActivity = false}) {
    final state = readState();
    final message = cloudSyncErrorMessage(error);
    if (!resetActivity && state.error == message) return;
    writeState(
      state.copyWith(
        activityStatus: resetActivity ? CloudSyncActivityStatus.idle : null,
        clearProgress: resetActivity,
        error: message,
        logs: [
          ...state.logs.length > 99
              ? state.logs.sublist(state.logs.length - 99)
              : state.logs,
          CloudSyncLogEntry(time: DateTime.now(), message: message),
        ],
      ),
    );
  }
}

String cloudSyncErrorMessage(Object error) => switch (error) {
  CloudBackendException() => error.message,
  CloudCryptoException() => error.message,
  CloudFormatException() => '远端备份格式或完整性校验失败：${error.message}',
  StateError() => error.message,
  FormatException() => '保存的同步配置或旧备份信息无法读取。',
  _ => '同步失败，请检查网络、服务商地址与账号权限后重试。',
};
