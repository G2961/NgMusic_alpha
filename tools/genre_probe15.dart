// Разведка v33: полный справочник жанров из select на /audio/browse.
// Запуск: dart run tools/genre_probe15.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse?inner=1'),
      headers: {'User-Agent': ua});
  final b = r.body;

  final sel = RegExp(r'<select[^>]*name="genre"[^>]*>([\s\S]*?)</select>')
      .firstMatch(b);
  if (sel == null) {
    print('select не найден');
    return;
  }
  final inner = sel.group(1)!;
  print('select найден, длина ${inner.length}');

  for (final m in RegExp(r'<option value="(\d+)"[^>]*>\s*([^<]+?)\s*</option>')
      .allMatches(inner)) {
    print('${m.group(1)} = ${m.group(2)}');
  }
}
