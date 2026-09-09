// Разведка v25: как РЕАЛЬНО работает фильтр жанра: смотрим inner=1
// (как дергает приложение) и сравниваем. Запуск: dart run tools/genre_probe8.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<List<String>> ids(String url) async {
  final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua});
  final set = RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1)!)
      .toList();
  print('$url\n  -> ${r.statusCode}, len=${r.body.length}, треков: ${set.length}');
  return set;
}

Future<void> main() async {
  // Как в приложении: ?genre=X&inner=1
  final g4i = await ids('https://www.newgrounds.com/audio/browse?genre=4&inner=1');
  final g15i = await ids('https://www.newgrounds.com/audio/browse?genre=15&inner=1');
  print('g4 ids: ${g4i.take(5)}');
  print('g15 ids: ${g15i.take(5)}');
}
