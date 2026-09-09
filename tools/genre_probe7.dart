// Разведка v24: genre= работает вообще? Сравниваем БЕЗ параметров,
// с genre=4 и путь-стиль. Запуск: dart run tools/genre_probe7.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<List<String>> ids(String url) async {
  final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua});
  final set = RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1)!)
      .toList();
  print('$url\n  -> ${r.statusCode}, треков: ${set.length}, первые: ${set.take(3)}');
  return set;
}

bool _sameSet(List<String> a, List<String> b) {
  final s = b.toSet();
  return a.length == b.length && a.every(s.contains);
}

Future<void> main() async {
  final base = await ids('https://www.newgrounds.com/audio/browse');
  final g4 = await ids('https://www.newgrounds.com/audio/browse?genre=4');
  final pathStyle =
      await ids('https://www.newgrounds.com/audio/browse/genre/country');

  print('base == genre4: ${_sameSet(base, g4)}');
  print('base == path:   ${_sameSet(base, pathStyle)}');
  print('genre4 == path: ${_sameSet(g4, pathStyle)}');

  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse/genre/country'),
      headers: {'User-Agent': ua});
  final spans = RegExp(r'class="detail-description"[^>]*>([^<]+)<')
      .allMatches(r.body)
      .map((m) => m.group(1)!.trim())
      .toSet()
      .toList();
  print('жанры в path-country: $spans');
}
