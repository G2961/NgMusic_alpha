// Разведка v37: Brit Pop (22) и Bluegrass (1) пустые — то ли жанр мёртв,
// то ли карточки без detail-description. Проверяем руками.
// Запуск: dart run tools/genre_probe19.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  for (final n in [22, 1]) {
    final r = await http.get(
        Uri.parse('https://www.newgrounds.com/audio/browse?genre=$n&inner=1'),
        headers: {'User-Agent': ua});
    final ids =
        RegExp(r'data-hub-id="(\d+)"').allMatches(r.body).map((m) => m.group(1)).toList();
    print('genre=$n: треков=${ids.length}');
    if (ids.isNotEmpty) {
      // Первая карточка целиком.
      final i = r.body.indexOf('data-hub-id="${ids.first}"');
      print(r.body
          .substring(i, (i + 600).clamp(0, r.body.length))
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' '));
    }
  }
}
