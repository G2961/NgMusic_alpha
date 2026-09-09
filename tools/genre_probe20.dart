// Разведка v41: работает ли ?genre= на /audio/featured и /audio/popular.
// Запуск: dart run tools/genre_probe20.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final tests = [
    'https://www.newgrounds.com/audio/featured?inner=1',
    'https://www.newgrounds.com/audio/featured?genre=15&inner=1',
    'https://www.newgrounds.com/audio/popular?genre=15&inner=1',
    'https://www.newgrounds.com/audio/browse?genre=15&inner=1',
  ];
  for (final url in tests) {
    final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua});
    final genres = RegExp(r'class="detail-description"[^>]*>\s*(?:Song|Loop) - ([^<]+?)\s*<')
        .allMatches(r.body)
        .map((m) => m.group(1)!.trim())
        .where((g) => g.isNotEmpty)
        .toSet();
    print('$url\n  -> жанры карточек: $genres');
  }
}
