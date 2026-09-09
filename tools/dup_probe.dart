// Разведка v38: дубликаты. 1) отличается ли offset=30 от offset=0?
// 2) сколько реально треков на странице. Запуск: dart run tools/dup_probe.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<List<String>> ids(String url) async {
  final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua});
  final list = RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1)!)
      .toList();
  print('$url -> ${list.length} шт: ${list.take(3)}…${list.length > 3 ? list.sublist(list.length - 2) : ''}');
  return list;
}

Future<void> main() async {
  final p0 = await ids('https://www.newgrounds.com/audio/browse?inner=1');
  final p24 = await ids('https://www.newgrounds.com/audio/browse?offset=24&inner=1');
  final p30 = await ids('https://www.newgrounds.com/audio/browse?offset=30&inner=1');

  print('p0∩p24: ${p0.toSet().intersection(p24.toSet()).length}');
  print('p0∩p30: ${p0.toSet().intersection(p30.toSet()).length}');
  print('внутри p0 дублей: ${p0.length} vs ${p0.toSet().length}');
  print('внутри p24 дублей: ${p24.length} vs ${p24.toSet().length}');
}
