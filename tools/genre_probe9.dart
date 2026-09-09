// Разведка v26: сверка жанров карточек с фильтром. Качаем ?genre=15 и
// /genre/heavy-metal, сверяем жанры в карточках. Запуск: dart run tools/genre_probe9.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<(List<String>, Set<String>)> fetch(String url) async {
  final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua});
  final ids = RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1)!)
      .toList();
  final genres = RegExp(r'class="detail-description"[^>]*>([^<]+)<')
      .allMatches(r.body)
      .map((m) => m.group(1)!.trim())
      .toSet();
  return (ids, genres);
}

Future<void> main() async {
  final (g15, g15genres) =
      await fetch('https://www.newgrounds.com/audio/browse?genre=15&inner=1');
  final (heavy, heavyGenres) = await fetch(
      'https://www.newgrounds.com/audio/browse/genre/heavy-metal');
  final (base, baseGenres) =
      await fetch('https://www.newgrounds.com/audio/browse?inner=1');

  print('genre=15: ${g15.length} треков, жанры: ${g15genres.toList()}');
  print('heavy-metal: ${heavy.length} треков, жанры: ${heavyGenres.toList()}');
  print('base: ${base.length} треков');
  print('g15 == heavy: ${g15.toSet().length} vs ${heavy.toSet().length}');
  final inter = g15.toSet().intersection(heavy.toSet());
  print('пересечение g15 ∩ heavy: ${inter.length}');
  print('пересечение g15 ∩ base: ${g15.toSet().intersection(base.toSet()).length}');
}
