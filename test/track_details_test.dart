// Парсинг страницы трека `/audio/listen/{id}` на сохранённой копии — без сети.
// Разметку проверяли по живой странице (см. test/fixtures) и по ng2015/audioData.js.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/data/model/track.dart';
import 'package:ngmusic/data/repository/ng_repository.dart';

Track _blank() => Track(
      id: '1572356',
      title: 'Xenoglossy',
      artist: '8-BiTek',
      genre: '',
      iconUrl: '',
      duration: 0,
      audioType: 3,
    );

void main() {
  test('sidestats со страницы трека разбираются в поля Track', () {
    final html =
        File('test/fixtures/listen_1572356.html').readAsStringSync();
    final track = _blank();

    NgRepository().parseListenDetails(track, html);

    expect(track.listens, '3,754');
    expect(track.downloads, '53');
    expect(track.votes, '26');
    expect(track.faves, '11');
    expect(track.score, '4.78');
    expect(track.uploaded, 'May 27, 2026');
    expect(track.genre, 'Hip Hop - Olskool');
    expect(track.fileInfo, contains('MB'));
    expect(track.fileInfo, contains('Song'));
    expect(track.description, contains('random garba'));
    expect(track.license, contains('Please contact me'));
  });

  test('ul.trophies даёт награды, включая Frontpaged', () {
    final track = _blank();
    NgRepository().parseListenDetails(track, '''
      <ul class="trophies">
        <li class="frontpage"><div class="flex-1 padded-vert">
          <strong>Frontpaged</strong> <a href="/fpa/audio/6/2026">June 17, 2026</a>
        </div></li>
        <li class="monthly4"><div><strong>Monthly 4th Place</strong> June 2026</div></li>
      </ul>
    ''');

    expect(track.awards.length, 2);
    expect(track.awards.first.kind, 'frontpage');
    expect(track.awards.first.label, 'Frontpaged');
    expect(track.awards.first.date, 'June 17, 2026');
    expect(track.awards[1].label, 'Monthly 4th Place');
    expect(track.awards[1].date, contains('June 2026'));
  });

  test('теги собираются из ссылок /audio/browse/tag/', () {
    final track = _blank();
    NgRepository().parseListenDetails(track, '''
      <a href="https://www.newgrounds.com/audio/browse/tag/chiptune">chiptune</a>
      <a href="https://www.newgrounds.com/audio/browse/tag/8bit">8bit</a>
      <a href="https://www.newgrounds.com/audio/browse/tag/chiptune">chiptune</a>
    ''');

    expect(track.tags, ['8bit', 'chiptune']);
  });

  test('обложка отдаётся кандидатами от _raw.png к превью', () {
    final track = _blank()..iconUrl = 'https://aicon.ngfiles.com/1572/1572356_medium.webp?f1';

    expect(track.artworkUrls.first,
        'https://aicon.ngfiles.com/1572/1572356_raw.png');
    expect(track.artworkUrls[1],
        'https://aicon.ngfiles.com/1572/1572356_raw.jpg');
    expect(track.artworkUrls[2],
        'https://aicon.ngfiles.com/1572/1572356_full.webp?f1');
  });
}
