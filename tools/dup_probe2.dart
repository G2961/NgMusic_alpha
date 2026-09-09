// Разведка v39: размер страницы у каждого эндпоинта хаба.
// Запуск: dart run tools/dup_probe2.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> cnt(String url) async {
  final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua});
  final n = RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1))
      .toSet()
      .length;
  print('$n  $url');
}

Future<void> main() async {
  await cnt('https://www.newgrounds.com/audio/featured');
  await cnt('https://www.newgrounds.com/audio/featured?offset=30&inner=1');
  await cnt('https://www.newgrounds.com/audio/popular?inner=1');
  await cnt('https://www.newgrounds.com/audio/popular?offset=30&inner=1');
  await cnt('https://www.newgrounds.com/audio/browse?sort=score&interval=month&inner=1');
  await cnt('https://www.newgrounds.com/audio/browse?sort=score&interval=month&offset=30&inner=1');
  await cnt('https://www.newgrounds.com/audio/browse?genre=15&inner=1');
  await cnt('https://www.newgrounds.com/audio/browse?genre=15&offset=30&inner=1');
}
