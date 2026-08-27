import 'package:flutter/material.dart';

/// 项目 Scaffold 兼容入口。
///
/// 旧版全屏 CRT/点阵覆盖层会干扰内容可读性，现统一由页面背景色和主题色面
/// 表达风格；保留该组件以避免调用方迁移成本。
class ThemedScaffold extends StatelessWidget {
  const ThemedScaffold({
    super.key,
    this.scaffoldKey,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.endDrawer,
    this.drawer,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? endDrawer;
  final Widget? drawer;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      endDrawer: endDrawer,
      drawer: drawer,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: backgroundColor,
    );
  }
}
