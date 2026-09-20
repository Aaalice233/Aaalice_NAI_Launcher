import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/theme_provider.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';

import '../../helpers/light_theme_contrast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleQuickTheme 只在深色拼贴朋克与 Bold Retro 浅色之间切换', () async {
    final container = createStorageFreeContainer();
    addTearDown(container.dispose);

    final notifier = container.read(themeNotifierProvider.notifier);
    expect(container.read(themeNotifierProvider), AppStyle.grungeCollage);

    await notifier.toggleQuickTheme();
    expect(container.read(themeNotifierProvider), AppStyle.boldRetro);

    await notifier.toggleQuickTheme();
    expect(container.read(themeNotifierProvider), AppStyle.grungeCollage);

    // 处于其它主题时优先切到浅色，而不是像 nextTheme 那样按枚举顺序轮转。
    await notifier.setTheme(AppStyle.neoDark);
    await notifier.toggleQuickTheme();
    expect(container.read(themeNotifierProvider), AppStyle.boldRetro);
  });
}
