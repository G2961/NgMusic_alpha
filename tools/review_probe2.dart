// Разведка: как выглядит СВОЙ отзыв на странице отзывов и какими
// эндпоинтами он редактируется/удаляется.
// Запуск: dart run tools/review_probe2.dart
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> headers(String cookie) => {
      'User-Agent': ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cookie': cookie,
    };

Future<void> main() async {
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // 1. Список СВОИХ отзывов на странице профиля.
  final mine = await http.get(
      Uri.parse('https://g2961.newgrounds.com/reviews/audio'),
      headers: headers(cookie));
  print('profile reviews -> ${mine.statusCode} len=${mine.body.length}');
  for (final m in RegExp(
          r'/reviews/portal/(\d+)/\d+|data-review-id="(\d+)"|/audio/listen/(\d+)')
      .allMatches(mine.body)
      .take(10)) {
    print('  ${m.group(0)}');
  }

  // Первый трек из своих отзывов.
  final trackId =
      RegExp(r'/reviews/portal/(\d+)/').firstMatch(mine.body)?.group(1) ??
          RegExp(r'/audio/listen/(\d+)').firstMatch(mine.body)?.group(1);
  if (trackId == null) {
    print('своих отзывов не нашлось');
    return;
  }
  print('trackId=$trackId');

  // 2. Страница отзывов трека с кукой: ищем СВОЮ карточку и её формы.
  final page = await http.get(
      Uri.parse('https://www.newgrounds.com/reviews/portal/$trackId/3/date/1'),
      headers: headers(cookie));
  final b = page.body;
  print('\nreviews page -> ${page.statusCode} len=${b.length}');

  final cards =
      RegExp(r'<div\s+class="pod-body review"[\s\S]{0,120}?data-review-id="(\d+)">')
          .allMatches(b)
          .toList();
  print('cards=${cards.length}');
  for (var i = 0; i < cards.length; i++) {
    final start = cards[i].end;
    final end = i + 1 < cards.length ? cards[i + 1].start : b.length;
    final block = b.substring(start, end);
    final isMine = block.contains('g2961');
    print('card#$i id=${cards[i].group(1)} mine=$isMine len=${block.length}');
    if (isMine) {
      // Печатаем блок целиком, вычищая переводы строк.
      print(block.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' '));
    }
  }

  // 3. Ищем во всей странице слова edit/delete рядом с reviews.
  for (final m in RegExp(
          r'<form[^>]*action="[^"]*review[^"]*"[^>]*>|/reviews/[a-z_]+/\d+[^"\x27 ]*',
          caseSensitive: false)
      .allMatches(b)
      .take(20)) {
    print('FORM/URL: ${m.group(0)}');
  }
}
