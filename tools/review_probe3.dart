// Разведка v3: свой отзыв на странице отзывов (входит ли g2961 в карточку),
// сравнение отдачи с кукой и без, и ответы форм edit/delete.
// Запуск: dart run tools/review_probe3.dart [trackId]
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> headers(String cookie) => {
      'User-Agent': ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cookie': cookie,
    };

void scan(String label, String b) {
  print('--- $label (len=${b.length}) ---');
  final cards = RegExp(
          r'<div\s+class="pod-body review"[\s\S]{0,120}?data-review-id="(\d+)">')
      .allMatches(b)
      .toList();
  print('cards=${cards.length}');
  for (var i = 0; i < cards.length; i++) {
    final start = cards[i].end;
    final end = i + 1 < cards.length ? cards[i + 1].start : b.length;
    final block = b.substring(start, end);
    final mine = block.contains('g2961');
    print('card#$i id=${cards[i].group(1)} mine=$mine len=${block.length}');
    if (mine) {
      print(block.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' '));
    }
  }
  // Формы/ссылки edit/delete и userkey-инпуты.
  for (final m in RegExp(
          r'<form[^>]*action="[^"]*(review|edit|delete)[^"]*"[^>]*>|<input[^>]*name="userkey"[^>]*>',
          caseSensitive: false)
      .allMatches(b)
      .take(8)) {
    print('FORM: ${m.group(0)}');
  }
}

Future<void> main(List<String> args) async {
  final trackId = args.isNotEmpty ? args.first : '1615369';
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // С кукой: на своей карточке должны появиться кнопки Edit/Delete.
  final auth = await http.get(
      Uri.parse('https://www.newgrounds.com/reviews/portal/$trackId/3/date/1'),
      headers: headers(cookie));
  print('auth page -> ${auth.statusCode}');
  scan('WITH cookie', auth.body);

  // Страница трека: есть ли там форма «edit your review» или «you reviewed this».
  final listen = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/listen/$trackId'),
      headers: headers(cookie));
  print('\nlisten -> ${listen.statusCode} len=${listen.body.length}');
  final lb = listen.body;
  for (final pat in [
    'reviews/create',
    'editReview',
    'review/edit',
    'You already reviewed',
    'your review',
    'g2961'
  ]) {
    final idx = lb.toLowerCase().indexOf(pat.toLowerCase());
    print('listen contains "$pat": ${idx >= 0}');
    if (idx >= 0 && pat != 'g2961') {
      print('  ctx: ${lb.substring(
          (idx - 120).clamp(0, lb.length), (idx + 260).clamp(0, lb.length))}'
          .replaceAll('\n', ' '));
    }
  }
}
