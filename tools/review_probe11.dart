// Разведка v11: контекст вокруг моей карточки и второй карточки — понять,
// есть ли заголовок секции отзывов и чей порядок. Плюс /reviews/portal отдаёт
// только ЧУЖИЕ? (сверка списка id). Запуск: dart run tools/review_probe11.dart [trackId]
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

  // Страница трека: id всех карточек.
  final listen = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/listen/$trackId'),
      headers: headers(cookie));
  print('listen page cards:');
  for (final m in RegExp(r'data-review-id="(\d+)"').allMatches(listen.body)) {
    print('  ${m.group(1)}');
  }

  // Отдельная страница отзывов: id всех карточек.
  final rev = await http.get(
      Uri.parse('https://www.newgrounds.com/reviews/portal/$trackId/3/date/1'),
      headers: headers(cookie));
  print('reviews page cards:');
  for (final m in RegExp(r'data-review-id="(\d+)"').allMatches(rev.body)) {
    print('  ${m.group(1)}');
  }
}
