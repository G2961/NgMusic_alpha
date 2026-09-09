// Разведка v14: как JS получает число реакций. Ищем в разметке отзывов
// hints: data-count-key, initTotals args, и пробуем ajax-варианты URL.
// Запуск: dart run tools/review_probe14.dart [trackId]
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> ajaxHeaders(String cookie) => {
      'User-Agent': ua,
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'X-Requested-With': 'XMLHttpRequest',
      'Cookie': cookie,
    };

Future<void> main(List<String> args) async {
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Вариант 1: visual-links-style батч-запрос не подходит; пробуем count.
  final candidates = [
    'https://www.newgrounds.com/reactions/count/2003/19683446',
    'https://www.newgrounds.com/favorites/reactions/type/2003/id/19683446?isAjaxRequest=1',
    'https://www.newgrounds.com/favorites/reactions/count/2003/19683446',
  ];
  for (final u in candidates) {
    try {
      final r = await http.get(Uri.parse(u), headers: ajaxHeaders(cookie));
      print('${r.statusCode} $u -> ${r.body.substring(0, r.body.length < 200 ? r.body.length : 200)}');
    } catch (e) {
      print('ERR $u: $e');
    }
  }
}
