// Разведка v9: как выглядит секция отзывов на странице трека, когда отзыв
// уже написан (create-формы нет). Ищем под с отзывами и его заголовок/плашку.
// Запуск: dart run tools/review_probe9.dart [trackId]
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

  // Все podtop-заголовки подов.
  print('=== pod heads ===');
  for (final m in RegExp(r'<h2[^>]*>([^<]{2,50})</h2>').allMatches(body)) {
    print('  ${m.group(1)}');
  }

  // Контекст перед моей карточкой (сколько символов — она первая в списке?).
  final revIdx = body.indexOf('data-review-id="19684145"');
  print('\nmy card at $revIdx of ${body.length}');
  // Ищем ближайший podtop / pod-head ПЕРЕД карточкой.
  final before = body.substring((revIdx - 3000).clamp(0, body.length), revIdx);
  final headM = RegExp(r'<h2[^>]*>([^<]+)</h2>').allMatches(before).toList();
  if (headM.isNotEmpty) {
    print('nearest h2 before: ${headM.last.group(1)}');
  }
  print('...${before.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').substring(before.length - 700)}');
}
