// Разведка v6: куда ведёт /reviews/edit/{id} — GET формы правки и её поля.
// Запуск: dart run tools/review_probe6.dart [reviewId]
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
  print('edit GET -> ${b.statusCode} len=${b.body.length}');
  final form = RegExp(r'<form[\s\S]{0,120}?action="([^"]*)"[\s\S]*?</form>')
      .firstMatch(b.body);
  if (form == null) {
    print('формы нет; первые 600 байт:');
    print(b.body.substring(0, 600));
    return;
  }
  print('form action=${form.group(1)}');
  for (final m in RegExp(
          r'<(input|textarea|select|button)[^>]*(name|type|value|placeholder)="[^"]*"[^>]*>')
      .allMatches(form.group(0)!)) {
    print('  ${m.group(0)!.replaceAll('\n', ' ')}');
  }
  // Фрагмент звёзд в форме (выбранный score).
  final star = RegExp(r'checked[^>]*|vote[^<>]{0,80}checked').allMatches(form.group(0)!);
  for (final m in star.take(5)) {
    print('STAR: ${m.group(0)}');
  }
}
