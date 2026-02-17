import 'package:flutter/material.dart';

/// 空状态信息模型
/// Empty state information model for displaying empty state UI
class EmptyStateInfo {
  final String title;
  final String? subtitle;
  final IconData icon;

  const EmptyStateInfo({
    required this.title,
    this.subtitle,
    required this.icon,
  });

  EmptyStateInfo copyWith({
    String? title,
    String? subtitle,
    IconData? icon,
  }) {
    return EmptyStateInfo(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
    );
  }
}
