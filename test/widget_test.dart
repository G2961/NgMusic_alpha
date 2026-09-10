// Смоук-тесты ретро-виджетов Newgrounds 2015.
//
// Полное приложение здесь не поднимается: ему нужны провайдеры, БД и плеер.
// Проверяем слой UI, который редизайнится.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ngmusic/data/model/playlist.dart';
import 'package:ngmusic/ui/theme/ng_theme.dart';
import 'package:ngmusic/ui/widgets/ng_chrome.dart';
import 'package:ngmusic/ui/widgets/ng_playlist_dialogs.dart';
import 'package:ngmusic/ui/widgets/ng_retro.dart';
import 'package:ngmusic/viewmodel/library_viewmodel.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ngTheme,
      home: Scaffold(backgroundColor: ngBlack, body: child),
    );

void main() {
  testWidgets('NgButton вызывает onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(
      Center(child: NgButton(label: 'Retry', onPressed: () => taps++)),
    ));

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
  });

  testWidgets('NgPod рисует заголовок и контент', (tester) async {
    await tester.pumpWidget(_wrap(
      const NgPod(
        icon: 'audio',
        title: 'Popular Audio',
        skin: NgSkin.green,
        child: Text('row'),
      ),
    ));

    expect(find.text('Popular Audio'), findsOneWidget);
    expect(find.text('row'), findsOneWidget);
  });

  testWidgets('NgAudioRow отдаёт тапы по треку и по автору', (tester) async {
    var track = 0;
    var artist = 0;
    await tester.pumpWidget(_wrap(
      NgAudioRow(
        index: 0,
        iconUrl: '',
        title: 'Song Title',
        genre: 'Trance',
        artist: 'SomeArtist',
        onTap: () => track++,
        onArtistTap: () => artist++,
      ),
    ));

    await tester.tap(find.text('Song Title'));
    // автор теперь строкой «by SomeArtist» под названием
    await tester.tap(find.textContaining('SomeArtist'));
    expect(track, 1);
    expect(artist, 1);
  });

  testWidgets('NgSection скрывает строки в свёрнутом состоянии', (tester) async {
    var toggles = 0;

    Widget build(bool collapsed) => _wrap(
          NgSection(
            label: 'Local',
            icon: 'folder',
            count: 2,
            collapsed: collapsed,
            onToggle: () => toggles++,
            children: const [Text('first row'), Text('second row')],
          ),
        );

    await tester.pumpWidget(build(false));
    expect(find.text('LOCAL'), findsOneWidget);
    expect(find.text('(2)'), findsOneWidget);
    final expandedHeight = tester.getSize(find.byType(NgSection)).height;

    await tester.tap(find.text('LOCAL'));
    expect(toggles, 1);

    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    // Свёрнутая секция схлопывается до одного заголовка: AnimatedCrossFade
    // держит строки в дереве, но места они не занимают.
    expect(find.text('LOCAL'), findsOneWidget);
    final collapsedHeight = tester.getSize(find.byType(NgSection)).height;
    expect(collapsedHeight, lessThan(expandedHeight));
  });

  testWidgets('диалог создания отдаёт имя и выбранное место', (tester) async {
    NgNewPlaylist? result;

    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => Center(
        child: NgButton(
          label: 'open',
          onPressed: () async {
            result =
                await showNgCreatePlaylistDialog(context, canUseNg: true);
          },
        ),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Mixtape');
    await tester.tap(find.text('Newgrounds'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Mixtape');
    expect(result?.target, PlaylistTarget.newgrounds);
  });

  testWidgets('без входа вариант Newgrounds не выбирается', (tester) async {
    NgNewPlaylist? result;

    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => Center(
        child: NgButton(
          label: 'open',
          onPressed: () async {
            result = await showNgCreatePlaylistDialog(
              context,
              canUseNg: false,
              // Предвыбор NG должен быть проигнорирован без сессии.
              target: PlaylistTarget.newgrounds,
            );
          },
        ),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Offline');
    await tester.tap(find.text('Newgrounds'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result?.target, PlaylistTarget.local);
  });

  test('is_ng переживает круг через Map — иначе секции избранного слипнутся', () {
    const fav = Favorite(
      trackId: '1572356',
      title: 'Track',
      artist: 'Someone',
      iconUrl: '',
      duration: 61,
      addedAt: 1,
      isNg: true,
    );
    expect(fav.toMap()['is_ng'], 1);
    expect(Favorite.fromMap(fav.toMap()).isNg, isTrue);
    // Строки из базы v2 колонки не имеют — такие сердечки считаются локальными.
    final legacy = Map<String, dynamic>.from(fav.toMap())..remove('is_ng');
    expect(Favorite.fromMap(legacy).isNg, isFalse);
  });

  testWidgets('выделенная плашка навбара подкрашена акцентом', (tester) async {
    // 2024: у выделенной плашки линия в полную яркость акцента + градиентная
    // подсветка снизу; у неактивной — та же линия, но приглушённая (alpha
    // 0.45, т.к. без progress у соседей activation = 0).
    Widget build(int index) => _wrap(NgNavPlates(
          labels: const ['Featured', 'New'],
          index: index,
          onSelect: (_) {},
          accents: const [NgAccent.blue, NgAccent.red],
        ));

    Color? bottomBorderColor(WidgetTester t, String label) {
      final plates = t.widgetList<NgNavPlate>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(NgNavPlate),
        ),
      );
      if (plates.isEmpty) return null;
      final plate = plates.first;
      // Достаём Container.decoration через дерево.
      final containerFinder = find.descendant(
        of: find.byWidget(plate),
        matching: find.byType(Container),
      );
      if (containerFinder.evaluate().isEmpty) return null;
      for (final c in containerFinder.evaluate()) {
        final widget = c.widget;
        if (widget is Container && widget.decoration is BoxDecoration) {
          final b = (widget.decoration as BoxDecoration).border;
          if (b is Border) {
            final side = b.bottom;
            return side.color == Colors.transparent ? null : side.color;
          }
        }
      }
      return null;
    }

    await tester.pumpWidget(build(0));
    final selected = bottomBorderColor(tester, 'Featured');
    final idle = bottomBorderColor(tester, 'New');

    expect(selected, isNotNull);
    expect(idle, isNotNull);
    // Выделенная — синяя полной яркости.
    expect(selected!.b, greaterThan(selected.r));
    // Невыделенная — тоже цветная (красный акцент), но приглушённая:
    // alpha 0.45 → смешение с чёрным фоном, R всё равно доминирует.
    expect(idle!.r, greaterThan(idle.b));
    expect(idle.a, closeTo(0.45, 0.01));
  });
}
