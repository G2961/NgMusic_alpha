// Разведка v13: сколько реакций у карточек (число приходит отдельным запросом
// в элемент reaction-totals). Запуск: dart run tools/review_probe13.dart [trackId]
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
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Число реакций отдаёт эндпоинт реакций (как для избранного).
  for (final rid in ['19683446', '19680354', '19684145']) {
    final url =
        'https://www.newgrounds.com/favorites/reactions/type/2003/id/$rid';
    final r = await http.get(Uri.parse(url), headers: headers(cookie));
    final nums = RegExp(r'>\s*(\d+)\s*<').allMatches(r.body).toList();
    print('reactions/$rid -> ${r.statusCode} len=${r.body.length} '
        'numbers=${nums.take(4).map((m) => m.group(1)).toList()}');
  }
}
