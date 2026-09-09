// Разведка v20: где на /audio/browse живёт сайдбар жанров — ищем любые
// конструкции с "genre" в тексте страницы. Запуск: dart run tools/genre_probe3.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(Uri.parse('https://www.newgrounds.com/audio/browse'),
      headers: {'User-Agent': ua});
  final b = r.body;
  print('len=${b.length}');

  // Все вхождения слова genre с контекстом.
  var count = 0;
  for (final m in RegExp(r'genre').allMatches(b)) {
    final i = m.start;
    final ctx = b
        .substring((i - 120).clamp(0, i), (i + 150).clamp(0, b.length))
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    print('[$i] $ctx');
    if (++count >= 15) break;
  }
}
