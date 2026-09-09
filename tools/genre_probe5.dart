// Разведка v22: slug-жанры. Проверяем /audio/browse/genre/<slug> и наличие
// поджанров в разметке. Запуск: dart run tools/genre_probe5.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  // 1. Группа по slug.
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse/genre/metal-rock'),
      headers: {'User-Agent': ua});
  print('metal-rock -> ${r.statusCode} len=${r.body.length}');
  final genres = <String>[];
  for (final m in RegExp(r'<dd>\s*([^<]+?)\s*</dd>').allMatches(r.body)) {
    genres.add(m.group(1)!);
  }
  print('dd-поля (жанры треков): ${genres.take(12).toList()}');
  final ids = RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1))
      .toList();
  print('треков: ${ids.length}, первые: ${ids.take(5)}');

  // 2. Поджанры: ищем submenu метал-рока.
  final b = r.body;
  final i = b.indexOf('Heavy Metal');
  if (i > 0) {
    print('\n=== Heavy Metal ctx ===');
    print(b
        .substring((i - 250).clamp(0, i), (i + 250).clamp(0, b.length))
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' '));
  }
}
