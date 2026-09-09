import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/ui/theme/ng_theme.dart';
import 'package:ngmusic/ui/widgets/ng_player.dart';
import 'package:ngmusic/ui/widgets/ng_retro.dart';

/// Плеер собирается из `NgPlayerStage` + подов внутри скролла — ровно так, как
/// его строит `PlayerScreen`. Тест ловит ошибки лейаута/отрисовки на реальной
/// метрике телефона (Pixel 6: 1080×2400 @2.625).
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 2.625;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('плеер целиком раскладывается и рисуется', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ngTheme,
      home: Scaffold(
        backgroundColor: ngBlack,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(height: 44, color: ngBlack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  child: Column(
                    children: [
                      const NgPlayerStage(
                        playing: true,
                        position: Duration(seconds: 42),
                        duration: Duration(minutes: 3, seconds: 20),
                      ),
                      const SizedBox(height: 10),
                      const NgPod.list(
                        icon: 'audio',
                        title: 'Track Info',
                        skin: NgSkin.green,
                        child: NgInfoTable(
                          skin: NgSkin.green,
                          items: [
                            NgInfoItem('Genre', 'Song - Ambient'),
                            NgInfoItem('Score', '4.20 / 5.00',
                                below: NgStars(score: 4.2)),
                            NgInfoItem('Listens', '1,024'),
                          ],
                        ),
                      ),
                      NgPod(
                        icon: 'user',
                        title: 'sqooqs',
                        skin: NgSkin.green,
                        action: NgPlateLink(label: 'Profile »', onTap: () {}),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('Follow to keep up with new '
                                  'submissions.', style: ngBody),
                            ),
                            const SizedBox(width: 10),
                            NgButton(
                                label: 'Follow',
                                icon: 'user-add',
                                onPressed: () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.text('Track Info'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);

    // компактная сцена — только два бара (44 + 48) и рамка
    final stage = tester.getSize(find.byType(NgPlayerStage));
    expect(stage.width, greaterThan(300));
    expect(stage.height, lessThan(120));
  });

  testWidgets('иконки трофеев режутся из спрайта', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            NgTrophyIcon(kind: 'frontpage', size: 28),
            NgTrophyIcon(kind: 'daily1'),
            NgTrophyIcon(kind: 'monthly2'),
            // неизвестный класс не должен падать
            NgTrophyIcon(kind: 'whatever'),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(NgTrophyIcon.knows('frontpage'), isTrue);
    expect(NgTrophyIcon.knows('whatever'), isFalse);
    expect(tester.getSize(find.byType(NgTrophyIcon).first), const Size(28, 28));
  });
}
