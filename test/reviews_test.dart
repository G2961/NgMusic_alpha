// Разбор отзывов и ответа голосования — на фрагментах живой разметки NG,
// без сети (проверено запросами из tools/review_probe.dart).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/data/repository/ng_repository.dart';

void main() {
  final repo = NgRepository();

  test('parseReviews: карточки, авторы, звёзды, текст, пагинация', () {
    const html = '''
<div class="itemlist" data-footer="Page</span> 1 of 56">
<div class="pod-body review" id="review_107930876a8f1ad3b758d" data-review-id="10793087">
  <a href="https://exlord.newgrounds.com" title="Exlord">Exlord</a>
  <image href="https://uimg.ngfiles.com/a/1.jpg" alt="avatar"/>
  <span class="star-score" title="Score: 4.50"><span style="width:90%"></span></span>
  <time datetime="2026-05-02">2026-05-02 14:03:11</time>
  <div class="review-body ">Great &amp; &#039;dark&#039; track, love &lt;it&gt;</div>
</div>
<div class="pod-body review" id="review_52416576a8f1ad3ba0af" data-review-id="5241657">
  <a href="https://some-user.newgrounds.com" title="Some User">Some User</a>
  <time datetime="2026-01-01">Jan 1, 2026</time>
  <div class="review-body no-score">Not bad</div>
</div>
</div>
''';
    final items = repo.parseReviews(html);
    expect(items.length, 2);

    expect(items[0].id, '10793087');
    expect(items[0].authorSlug, 'exlord');
    expect(items[0].author, 'Exlord');
    expect(items[0].avatarUrl, isNotEmpty);
    expect(items[0].score, 4.5);
    // Дата сокращается до «месяц число, год».
    expect(items[0].date, 'May 2, 2026');
    // Сущности и теги вычищены.
    expect(items[0].body, "Great & 'dark' track, love <it>");

    // Вторая карточка — без звёзд: score 0.
    expect(items[1].score, 0);
    expect(items[1].hasScore, isFalse);
    expect(items[1].body, 'Not bad');
  });

  test('parseReviews: NG-дата с временем сокращается до «May 2, 2026»', () {
    const html = '''
<div class="pod-body review" id="review_1" data-review-id="1">
  <a href="https://u.newgrounds.com" title="U">U</a>
  <time>2026-05-02 14:03:11</time>
</div>
''';
    final items = repo.parseReviews(html);
    expect(items.single.date, 'May 2, 2026');
  });

  test('parseReviews: пустая страница отдаёт пустой список', () {
    expect(repo.parseReviews('<html><body></body></html>'), isEmpty);
  });

  test('vote-ответ: score/votes из sidestats, waiting-флаг', () {
    // sidestats — HTML-фрагмент внутри JSON; эскейпим через jsonEncode,
    // чтобы фикстура была честной.
    String voteBody(String sidestats) =>
        jsonEncode({'success': true, 'sidestats': sidestats});

    final ok = voteBody('<dl id="sidestats"><dt>Votes</dt><dd>1,234</dd></dl>'
        '<span id="score_number">4.36</span>');
    final res = repo.parseVoteResponsePublic(ok);
    expect(res, isNotNull);
    expect(res!.score, 4.36);
    expect(res.votes, 1234);
    expect(res.waiting, isFalse);

    const waiting = '{"success":true,"sidestats":"Waiting for 4 more votes"}';
    final res2 = repo.parseVoteResponsePublic(waiting);
    expect(res2, isNotNull);
    expect(res2!.waiting, isTrue);
    expect(res2.score, isNull);

    // Без sidestats — не ошибка, просто сказать нечего.
    expect(repo.parseVoteResponsePublic('{"success":false}'), isNull);
  });
}
