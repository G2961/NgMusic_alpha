// Разведка v4: где именно на странице трека лежит МОЙ отзыв и как
// NG помечает «you already voted / your vote». Запуск: dart run tools/review_probe4.dart [trackId]
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

  final b = (await http.get(
          Uri.parse('https://www.newgrounds.com/audio/listen/$trackId'),
          headers: headers(cookie)))
      .body;

  // Все вхождения g2961 с контекстом.
  print('=== g2961 contexts ===');
  for (final m in RegExp(r'g2961').allMatches(b).take(10)) {
    final i = m.start;
    print(
        '[${i.toString().padLeft(6)}] ...${b.substring((i - 200).clamp(0, i), (i + 200).clamp(0, b.length)).replaceAll('\n', ' ')}...\n');
  }

  // votebar: отмечен ли выбор (класс voted / checked).
  print('=== votebar state ===');
  final votebarM = RegExp(r'<form[^>]*id="votebar"[\s\S]{0,3000}?</form>')
      .firstMatch(b);
  if (votebarM != null) {
    final v = votebarM.group(0)!.replaceAll('\n', ' ');
    print(v.substring(0, v.length < 2200 ? v.length : 2200));
  } else {
    print('votebar формы нет (уже голосовал?)');
    for (final m in RegExp(r'.{140}votebar.{260}').allMatches(b).take(4)) {
      print(m.group(0)!.replaceAll('\n', ' '));
    }
  }
}
