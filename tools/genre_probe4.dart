// Разведка v21: сайдбар жанров аудио — ищем блок sidestats/sideNav на /audio.
// Запуск: dart run tools/genre_probe4.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(Uri.parse('https://www.newgrounds.com/audio'),
      headers: {'User-Agent': ua});
  final b = r.body;

  for (final pat in ['sidestats', 'sideNav', 'audio/browse?genre', 'Ambient',
    'Easy Listening', 'Heavy Metal', 'Drum N Bass']) {
    final i = b.indexOf(pat);
    print('$pat -> $i');
  }

  // Контекст вокруг "Easy Listening" — это сайдбар жанров аудио.
  final i = b.indexOf('Easy Listening');
  if (i > 0) {
    print('\n=== SIDEBAR CONTEXT ===');
    print(b
        .substring((i - 300).clamp(0, i), (i + 3000).clamp(0, b.length))
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' '));
  }
}
