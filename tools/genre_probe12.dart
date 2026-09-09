// Разведка v29: добираем недостающие ID поджанров (22, 30-38 и пр.)
// и сверяем группы (id групп в под-меню NG другие, не жанровые).
// Запуск: dart run tools/genre_probe12.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<Set<String>> genresOf(String q) async {
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse?$q&inner=1'),
      headers: {'User-Agent': ua});
  return RegExp(r'class="detail-description"[^>]*>([^<]+)<')
      .allMatches(r.body)
      .map((m) => m.group(1)!.trim())
      .toSet();
}

Future<void> main() async {
  // Ищем недостающие: Brit Pop, Heavy Metal есть (15). Где Brit Pop?
  // Проверяем жанровые «мусорные» диапазоны как группы: 30..38 дают дефолт
  // (это, похоже, ID из другого справочника — portal). Пробуем строковые slug.
  for (final q in ['genre=brit-pop', 'genre=bluegrass', 'genre=blues',
    'genre=goth', 'genre=ska', 'genre=world', 'genre=drama',
    'genre=voice-demo', 'genre=comedy', 'genre=creepypasta',
    'genre=a-capella', 'genre=spoken-word', 'genre=informational']) {
    final g = await genresOf(q);
    print('$q -> $g');
  }
}
