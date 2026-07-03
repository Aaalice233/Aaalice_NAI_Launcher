import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/video_player_widget.dart';
import 'package:video_player/video_player.dart';

void main() {
  test('diagnostic video source omits query and fragment values', () {
    final source = describeOnlineGalleryVideoSourceForDiagnostics(
      'https://cdn.example.test/assets/video/sample.mp4?token=raw-secret#frag',
    );

    expect(source, 'https://cdn.example.test/sample.mp4');
    expect(source, isNot(contains('raw-secret')));
    expect(source, isNot(contains('frag')));
  });

  testWidgets(
    'controls update from the video value without rebuilding the parent widget',
    (tester) async {
      final videoValue = ValueNotifier<VideoPlayerValue>(
        const VideoPlayerValue(
          duration: Duration(seconds: 10),
          position: Duration(seconds: 1),
          isInitialized: true,
        ),
      );
      var parentBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _CountingParent(
              onBuild: () => parentBuilds++,
              child: OnlineGalleryVideoControls(
                valueListenable: videoValue,
                showControls: true,
                onTogglePlayPause: () {},
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(parentBuilds, 1);
      expect(find.text('00:01'), findsOneWidget);

      videoValue.value = const VideoPlayerValue(
        duration: Duration(seconds: 10),
        position: Duration(seconds: 3),
        isInitialized: true,
        isPlaying: true,
      );
      await tester.pump();

      expect(parentBuilds, 1);
      expect(find.text('00:03'), findsOneWidget);
    },
  );

  testWidgets('controls report slider changes as seek durations', (
    tester,
  ) async {
    final seeks = <Duration>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineGalleryVideoControls(
            valueListenable: ValueNotifier<VideoPlayerValue>(
              const VideoPlayerValue(
                duration: Duration(seconds: 10),
                position: Duration(seconds: 2),
                isInitialized: true,
              ),
            ),
            showControls: true,
            onTogglePlayPause: () {},
            onSeek: seeks.add,
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0.5);

    expect(seeks, [const Duration(seconds: 5)]);
  });
}

class _CountingParent extends StatelessWidget {
  const _CountingParent({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}
