// Разведка v28: подбираем числовые ID поджанров перебором genre=N
// и сверкой жанров карточек. Запуск: dart run tools/genre_probe11.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<Set<String>> genresOf(int n) async {
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse?genre=$n&inner=1'),
      headers: {'User-Agent': ua});
  return RegExp(r'class="detail-description"[^>]*>([^<]+)<')
      .allMatches(r.body)
      .map((m) => m.group(1)!.trim())
      .toSet();
}

Future<void> main() async {
  // Известно: 15=Heavy Metal, 4=Country, 5=Ambient(?), 7=Drum N Bass(?).
  // Пробегаем 1..70 и пишем карту. Фильтр пустых (не-жанр) ответов — по жанрам карточек.
  for (var n = 1; n <= 70; n++) {
    final g = await genresOf(n);
    if (g.isEmpty) continue;
    print('$n -> $g');
  }
}
