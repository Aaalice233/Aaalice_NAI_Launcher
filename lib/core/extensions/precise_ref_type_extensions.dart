import 'package:flutter/material.dart';

import '../enums/precise_ref_type.dart';

/// UI 扩展方法 for [PreciseRefType]
extension PreciseRefTypeUI on PreciseRefType {
  /// 获取类型的本地化显示名称
  String getDisplayName({
    required String character,
    required String style,
    required String characterAndStyle,
  }) {
    return switch (this) {
      PreciseRefType.character => character,
      PreciseRefType.style => style,
      PreciseRefType.characterAndStyle => characterAndStyle,
    };
  }

  /// 获取类型对应的图标
  IconData get icon {
    return switch (this) {
      PreciseRefType.character => Icons.person,
      PreciseRefType.style => Icons.palette,
      PreciseRefType.characterAndStyle => Icons.auto_awesome,
    };
  }
}
