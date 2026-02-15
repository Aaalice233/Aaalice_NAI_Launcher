import 'package:flutter/material.dart';

/// 加载状态覆盖层
///
/// 点击选择文件后立即显示，解决"等待感"问题
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '正在打开...',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
