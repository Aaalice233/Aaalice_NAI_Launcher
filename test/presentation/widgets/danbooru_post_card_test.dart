import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_post_card.dart';

void main() {
  group('DanbooruPostCard Selection', () {
    testWidgets('选中状态应显示勾选图标', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DanbooruPostCard(
                post: DanbooruPost(id: 123, tagString: '1girl blue_hair solo'),
                itemWidth: 200,
                isFavorited: false,
                isSelected: true,
                onTap: () {},
                onTagTap: (_) {},
                onFavoriteToggle: () {},
                onSelectionToggle: () {},
              ),
            ),
          ),
        ),
      );

      // 选中状态应该显示勾选图标
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('未选中状态应显示加号图标', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DanbooruPostCard(
                post: DanbooruPost(id: 123, tagString: '1girl blue_hair solo'),
                itemWidth: 200,
                isFavorited: false,
                isSelected: false,
                onTap: () {},
                onTagTap: (_) {},
                onFavoriteToggle: () {},
                onSelectionToggle: () {},
              ),
            ),
          ),
        ),
      );

      // 未选中状态应该显示加号图标
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('点击复选框应触发 onSelectionToggle', (tester) async {
      bool toggleCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DanbooruPostCard(
                post: DanbooruPost(id: 123, tagString: '1girl'),
                itemWidth: 200,
                isFavorited: false,
                isSelected: false,
                onTap: () {},
                onTagTap: (_) {},
                onFavoriteToggle: () {},
                onSelectionToggle: () => toggleCalled = true,
              ),
            ),
          ),
        ),
      );

      // 点击复选框区域
      await tester.tap(find.byType(Icon).first);
      await tester.pump();

      expect(toggleCalled, isTrue);
    });
  });
}
