// Разведка v40: featured/popular живут по своим правилам — сверяем пересечение
// соседних страниц у featured (там может быть рейтинг-карусель).
// Запуск: dart run tools/dup_probe3.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<Set<String>> ids(String url) async {
  final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua});
  return RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1)!)
      .toSet();
}

Future<void> main() async {
  final f0 = await ids('https://www.newgrounds.com/audio/featured');
  final f30 = await ids('https://www.newgrounds.com/audio/featured?offset=30&inner=1');
  final p0 = await ids('https://www.newgrounds.com/audio/popular?inner=1');
  final p30 = await ids('https://www.newgrounds.com/audio/popular?offset=30&inner=1');
  final s0 = await ids('https://www.newgrounds.com/audio/browse?sort=score&interval=month&inner=1');
  final s30 = await ids('https://www.newgrounds.com/audio/browse?sort=score&interval=month&offset=30&inner=1');
  print('featured 0∩30: ${f0.intersection(f30).length}');
  print('popular  0∩30: ${p0.intersection(p30).length}');
  print('score    0∩30: ${s0.intersection(s30).length}');
}
