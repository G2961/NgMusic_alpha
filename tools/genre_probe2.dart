// Разведка v19: жанровые ссылки со страницы /audio/browse (там сайдбар).
// Запуск: dart run tools/genre_probe2.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(Uri.parse('https://www.newgrounds.com/audio/browse'),
      headers: {'User-Agent': ua});
  print('audio/browse -> ${r.statusCode} len=${r.body.length}');

  // Все ссылки жанров в сайдбаре аудио.
  for (final m in RegExp(r'href="(/audio/browse/[^"]+)"')
      .allMatches(r.body)
      .toSet()
      .take(70)) {
    print(m.group(1));
  }
  // Также смотрим genre= параметры.
  print('--- query style ---');
  for (final m in RegExp(r'href="[^"]*\?[^"]*genre=([^&"]+)[^"]*"')
      .allMatches(r.body)
      .toSet()
      .take(20)) {
    print(m.group(0));
  }
}
