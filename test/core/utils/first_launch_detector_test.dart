import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/utils/first_launch_detector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'NAI Launcher',
      packageName: 'nai_launcher',
      version: '4.3.2',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('启动入口只读不订阅时，非首次启动检测跨过帧间隙仍正常完成', (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.firstLaunchVersion: '4.3.1',
    });

    final check = await _startCheckWithoutSubscription(tester);

    await expectLater(check.future, completes);
    final state = check.ref.read(firstLaunchNotifierProvider);
    expect(state.isFirstLaunch, isFalse);
    expect(state.hasSyncCompleted, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.firstLaunchVersion), '4.3.1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('启动入口只读不订阅时，首次启动检测跨过帧间隙仍记录当前版本', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final check = await _startCheckWithoutSubscription(tester);

    await expectLater(check.future, completes);
    final state = check.ref.read(firstLaunchNotifierProvider);
    expect(state.isFirstLaunch, isTrue);
    expect(state.isSyncing, isFalse);
    expect(state.hasSyncCompleted, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.firstLaunchVersion), '4.3.2');
    expect(tester.takeException(), isNull);
  });
}

/// 与主应用包装器相同：只 read notifier 发起检测，不建立订阅。
Future<({Future<void> future, WidgetRef ref})> _startCheckWithoutSubscription(
  WidgetTester tester,
) async {
  final detectorReady = Completer<FirstLaunchDetector>();
  late WidgetRef bootstrapRef;
  late BuildContext bootstrapContext;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firstLaunchDetectorProvider.overrideWith((ref) => detectorReady.future),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          bootstrapRef = ref;
          bootstrapContext = context;
          return const SizedBox();
        },
      ),
    ),
  );

  final future = bootstrapRef
      .read(firstLaunchNotifierProvider.notifier)
      .checkAndSync(bootstrapContext);
  // 检测器就绪前先走几帧：无订阅者的 autoDispose provider 会在此期间被回收
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  detectorReady.complete(FirstLaunchDetector());
  await tester.pump();
  return (future: future, ref: bootstrapRef);
}
