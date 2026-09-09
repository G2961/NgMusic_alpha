// Разведка v18: реальные ID жанров из разметки самого NG (sidebar аудио).
// Запуск: dart run tools/genre_probe.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(Uri.parse('https://www.newgrounds.com/audio'),
      headers: {'User-Agent': ua});
  print('audio home -> ${r.statusCode} len=${r.body.length}');
  final b = r.body;

  // Все ссылки с genre= или /genre/
  final links = <String>{};
  for (final m
      in RegExp(r'href="([^"]*genre[^"]*)"').allMatches(b)) {
    links.add(m.group(1)!);
  }
  print('--- genre links (${links.length}) ---');
  for (final l in links.take(60)) {
    print(l);
  }
}
