import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // 测试 SharedPreferences 读取
  final prefs = await SharedPreferences.getInstance();
  
  print('=== 检查 SharedPreferences ===');
  
  final imageSavePath = prefs.getString('image_save_path');
  print('image_save_path: $imageSavePath');
  
  // 打印所有 keys
  print('\n所有设置 keys:');
  for (final key in prefs.getKeys()) {
    final value = prefs.get(key);
    print('  - $key: $value');
  }
}
