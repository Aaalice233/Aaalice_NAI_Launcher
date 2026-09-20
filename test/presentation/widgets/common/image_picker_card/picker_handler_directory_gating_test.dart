import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/l10n/app_localizations_en.dart';
import 'package:nai_launcher/presentation/widgets/common/image_picker_card/_internal/picker_handler.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  test('iOS 上不调用目录选择器，直接按「已取消」返回', () async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.iOS,
    );
    final errors = <String>[];

    // 没有早退的话这里会打到 file_picker 的 MethodChannel 并抛
    // MissingPluginException，所以「返回 null 且没有错误回调」正好证明
    // 早退生效：iOS 的 getDirectoryPath 只能给出跨启动失效的一次性路径。
    final path = await PickerHandler.pickDirectory(
      l10n: AppLocalizationsEn(),
      onError: errors.add,
    );

    expect(path, isNull);
    expect(errors, isEmpty);
  });
}
