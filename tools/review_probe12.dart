// Разведка v12: разметка карточки ЧУЖОГО отзыва на /reviews/portal —
// звёзды (title), реакции (числа), флажок. Запуск: dart run tools/review_probe12.dart [trackId]
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> headers(String cookie) => {
      'User-Agent': ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cookie': cookie,
    };

Future<void> main(List<String> args) async {
  final trackId = args.isNotEmpty ? args.first : '1615369';
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final b = await http.get(
      Uri.parse('https://www.newgrounds.com/reviews/portal/$trackId/3/date/1'),
      headers: headers(cookie));
  final body = b.body;
  print('GET -> ${b.statusCode} len=${body.length}');

  // Заголовки звёзд: все варианты score-разметки.
  print('=== score markup ===');
  for (final m in RegExp(r'.{40}star-score.{140}').allMatches(body).take(4)) {
    print(m.group(0)!.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' '));
    print('---');
  }

  // Первая карточка целиком (до второй).
  final cards = RegExp(
          r'<div\s+class="pod-body review"[\s\S]{0,120}?data-review-id="(\d+)">')
      .allMatches(body)
      .toList();
  print('cards=${cards.length}');
  if (cards.isNotEmpty) {
    final start = cards.first.end;
    final end = cards.length > 1 ? cards[1].start : body.length;
    print('=== CARD#0 (${cards.first.group(1)}) ===');
    print(body
        .substring(start, end)
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' '));
  }

  // Реакции: числа в карточках.
  print('=== reaction numbers ===');
  for (final m in RegExp(
          r'initTotals\([^)]*\)|data-count-key="[^"]*"|reaction-totals[^>]*>[^<]*<')
      .allMatches(body)
      .take(8)) {
    print(m.group(0)!.replaceAll('\n', ' '));
  }
}
