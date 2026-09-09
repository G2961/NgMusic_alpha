// Разведка v16: отдаёт ли reaction-totals число при isAjaxRequest —
// печатаем область вокруг <a class="reaction-totals"> в AJAX-ответе.
// Запуск: dart run tools/review_probe16.dart [trackId]
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> ajaxHeaders(String cookie) => {
      'User-Agent': ua,
      'Accept': 'text/html,*/*;q=0.9',
      'X-Requested-With': 'XMLHttpRequest',
      'Cookie': cookie,
    };

Future<void> main(List<String> args) async {
  final trackId = args.isNotEmpty ? args.first : '1615369';
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // AJAX-пагинация отзывов — тот же URL, что и обычный, но с isAjaxRequest.
  final r = await http.get(
      Uri.parse(
          'https://www.newgrounds.com/reviews/portal/$trackId/3/date/1?isAjaxRequest=1'),
      headers: ajaxHeaders(cookie));
  final body = r.body;
  print('ajax reviews -> ${r.statusCode} len=${body.length}');

  final i = body.indexOf('reaction-totals');
  if (i > 0) {
    print(body
        .substring((i - 60).clamp(0, i), (i + 300).clamp(0, body.length))
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' '));
  } else {
    print('reaction-totals не найден в ajax-ответе');
  }
}
