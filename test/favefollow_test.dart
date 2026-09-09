// Разбор кнопки `favefollow` и пустышек `data-visual-link` — на сохранённых
// копиях реальной разметки, без сети.
//
// Почему это важно: в HTML NG всегда присутствуют ОБА состояния кнопки
// (`.favefollow-add` и `.favefollow-remove`), поэтому единственный признак
// «уже подписан / уже в избранном» — класс `active` на обёртке. Проверка по
// наличию `.following-user` возвращала true всегда, из-за чего статус подписки
// на странице артиста самопроизвольно переключался на «Подписан».

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/data/repository/ng_repository.dart';

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  final repo = NgRepository();

  test('обёртка с классом active означает «уже подписан»', () {
    final button = repo.parseFaveButton(
        _fixture('favefollow_active.html'), 'initFollowButton');

    expect(button, isNotNull);
    expect(button!.active, isTrue);
    expect(button.key, 'ff-g-gC4-EDoR');
    expect(button.userkey, isNotEmpty);
  });

  test('обёртка без active означает «не подписан», хотя remove-кнопка в DOM есть',
      () {
    final html = _fixture('favefollow_inactive.html');
    // Ровно та ловушка, на которую попадал старый парсер.
    expect(html, contains('following-user'));
    expect(html, contains('favefollow-remove'));

    final button = repo.parseFaveButton(html, 'initFollowButton');
    expect(button, isNotNull);
    expect(button!.active, isFalse);
    expect(button.key, 'ff-g-gC4-g80qa');
  });

  test('запрос другой кнопки на той же странице не находится', () {
    final button = repo.parseFaveButton(
        _fixture('favefollow_active.html'), 'initFavoriteButton');
    expect(button, isNull);
  });

  test('id плейлистов берутся из data-visual-link, а не из ссылок', () {
    final html = _fixture('playlists_page.html');
    // Ссылок /playlists/view/ на странице нет — на них ориентировался
    // старый getUserPlaylists, поэтому синхронизация всегда давала пустой список.
    expect(html, isNot(contains('/playlists/view/')));

    final ids = repo.visualLinkIds(html, 21000);
    expect(ids.length, 30);
    expect(ids.first, '546239');
    expect(ids, contains('505922'));
    // Порядок разметки сохраняется.
    expect(ids.indexOf('544887'), 1);
    // Аудио-пустышек на этой странице нет.
    expect(repo.visualLinkIds(html, 3), isEmpty);
  });
}
