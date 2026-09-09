// Разведка v10: где на странице трека лежат отзывы (заголовок podtop с
// «Reviews») и что идёт сразу после моей карточки (кнопка «Read More»?).
// Запуск: dart run tools/review_probe10.dart [trackId]
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

  final body = (await http.get(
          Uri.parse('https://www.newgrounds.com/audio/listen/$trackId'),
          headers: headers(cookie)))
      .body;

  final revIdx = body.indexOf('data-review-id="19684145"');
  // Заголовок «Reviews» обычно далеко выше карточек (под с plashкой «Read more»).
  for (final pat in ['>Reviews<', 'Reviews</', 'review-head', 'reviews-for',
      'Read More', 'read-more', 'reviews_url', 'review_count']) {
    final idx = body.indexOf(pat);
    print('$pat -> $idx');
    if (idx > 0) {
      print('  ${body.substring((idx-80).clamp(0,idx), (idx+180).clamp(0, body.length))}'
          .replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' '));
    }
  }
  // Отзывы вообще на странице трека или подгружаются?
  final cards = RegExp(r'data-review-id').allMatches(body).length;
  print('review cards on page: $cards');
}
