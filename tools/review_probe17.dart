// Разведка v17: какой URL дергает initTotals для числа реакций.
// Пробуем форматы favorites/reactions c типом 2003 как JSON.
// Запуск: dart run tools/review_probe17.dart [trackId]
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

  final candidates = [
    'https://www.newgrounds.com/favorites/reactions/totals/2003/19683446',
    'https://www.newgrounds.com/favorites/reactions/type/2003/id/19683446/show/1',
    'https://www.newgrounds.com/reactions/2003/19683446',
    'https://www.newgrounds.com/favorites/reactions/2003/19683446',
  ];
  for (final u in candidates) {
    try {
      final r = await http.get(Uri.parse(u), headers: ajaxHeaders(cookie));
      final snippet = r.body.length > 160 ? r.body.substring(0, 160) : r.body;
      print('${r.statusCode} ${u.split('nggrounds.com')[1]} -> $snippet');
    } catch (e) {
      print('ERR $u');
    }
  }
}
