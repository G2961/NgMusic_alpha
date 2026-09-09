// Разведка v30: добираем оставшиеся числовые ID (22, 30-38, 60-70 не дали
// жанра — значит надо искать в другом месте; сверяем с NG audio API поиска).
// Попробуем values из фильтров страницы browse: <option value="N">.
// Запуск: dart run tools/genre_probe13.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse'),
      headers: {'User-Agent': ua});
  final b = r.body;

  // <option value="N">Label</option> — справочник жанров фильтра.
  final opts = RegExp(r'<option value="(\d+)"[^>]*>\s*([^<]+?)\s*</option>')
      .allMatches(b)
      .map((m) => (m.group(1)!, m.group(2)!))
      .toList();
  print('options (${opts.length}):');
  for (final o in opts) {
    print('  ${o.$1} = ${o.$2}');
  }
}
