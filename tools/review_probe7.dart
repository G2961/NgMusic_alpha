// Разведка v7: на странице /reviews/edit/{id} ищем именно форму отзыва
// (не топсёрч) и как в ней отмечен score. Запуск: dart run tools/review_probe7.dart [reviewId]
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
  final reviewId = args.isNotEmpty ? args.first : '19684145';
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final b = (await http.get(
      Uri.parse('https://www.newgrounds.com/reviews/edit/$reviewId'),
      headers: headers(cookie)));
  final body = b.body;
  print('GET -> ${b.statusCode} len=${body.length}');

  // Все формы на странице.
  final forms =
      RegExp(r'<form[^>]*action="([^"]*)"[^>]*>').allMatches(body).toList();
  print('forms:');
  for (final f in forms) {
    print('  ${f.group(1)}');
  }

  // Ищем textarea — это форма отзыва; печатаем всю область вокруг.
  final ta = body.indexOf('<textarea');
  if (ta < 0) {
    print('textarea нет');
  } else {
    final from = body.lastIndexOf('<form', ta);
    final to = body.indexOf('</form>', ta);
    final form = body.substring(from, to + 7);
    print('\n=== REVIEW FORM (len=${form.length}) ===');
    print(form.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' '));
  }
}
