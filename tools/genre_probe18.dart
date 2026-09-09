// Разведка v36: Voice Acting / Podcasts не фильтруются числом — проверяем,
// отдают ли они треки через voice-жанры в карточках: genre=31 (menu id)?
// Проще: сверим, что фильтр browse для них без ID — убираем из модели
// поджанры этих групп и оставляем только реальные ID. Финальная проверка
// всех ID из справочника. Запуск: dart run tools/genre_probe18.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

const known = {
  '3': 'Classical', '18': 'Jazz', '51': 'Solo Instrument',
  '5': 'Ambient', '48': 'Chipstep', '6': 'Dance', '7': 'Drum N Bass',
  '41': 'Dubstep', '9': 'House', '59': 'Hyperpop', '8': 'Industrial',
  '20': 'New Wave', '58': 'Phonk', '57': 'Synthwave', '10': 'Techno',
  '11': 'Trance', '12': 'Video Game',
  '17': 'Hip Hop - Modern', '16': 'Hip Hop - Olskool', '47': 'Nerdcore',
  '21': 'R&B',
  '22': 'Brit Pop', '23': 'Classic Rock', '24': 'General Rock',
  '25': 'Grunge', '15': 'Heavy Metal', '26': 'Indie', '27': 'Pop', '28': 'Punk',
  '50': 'Cinematic', '49': 'Experimental', '13': 'Funk', '52': 'Fusion',
  '14': 'Goth', '39': 'Miscellaneous', '29': 'Ska', '19': 'World',
  '1': 'Bluegrass', '2': 'Blues', '4': 'Country',
};

Future<void> main() async {
  var ok = 0;
  var fail = 0;
  for (final e in known.entries) {
    final r = await http.get(
        Uri.parse('https://www.newgrounds.com/audio/browse?genre=${e.key}&inner=1'),
        headers: {'User-Agent': ua});
    final genres = RegExp(r'class="detail-description"[^>]*>\s*(?:Song|Loop) - ([^<]+?)\s*<')
        .allMatches(r.body)
        .map((m) => m.group(1)!.trim())
        .where((g) => g.isNotEmpty)
        .toSet();
    // Фильтр считается верным, если ВСЕ жанры карточек == ожидание.
    final expect = e.value;
    final good = genres.isNotEmpty && genres.every((g) => g == expect);
    if (good) {
      ok++;
    } else {
      fail++;
      print('FAIL ${e.key} ($expect): карточки=$genres');
    }
  }
  print('=== OK: $ok, FAIL: $fail ===');
}
