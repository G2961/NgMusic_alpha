// Разведка v23: сверка жанров — треки metal-rock правда метальные?
// Берём жанр первого трека из dd-полей по-другому + сравниваем выборки
// групп и поджанров на пересечение ID. Запуск: dart run tools/genre_probe6.dart
import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<List<String>> ids(String path) async {
  final r = await http.get(Uri.parse('https://www.newgrounds.com$path'),
      headers: {'User-Agent': ua});
  final set = RegExp(r'data-hub-id="(\d+)"')
      .allMatches(r.body)
      .map((m) => m.group(1)!)
      .toList();
  print('$path -> ${r.statusCode}, треков: ${set.length}');
  return set;
}

Future<void> main() async {
  final metal = await ids('/audio/browse/genre/metal-rock');
  final heavy = await ids('/audio/browse/genre/heavy-metal');
  final country = await ids('/audio/browse/genre/country');
  final easy = await ids('/audio/browse/genre/easy-listening');

  final overlapMH = metal.toSet().intersection(heavy.toSet()).length;
  final overlapMC = metal.toSet().intersection(country.toSet()).length;
  final overlapEC = easy.toSet().intersection(country.toSet()).length;
  print('metal ∩ heavy-metal: $overlapMH (ожидаемо >0, подмножество)');
  print('metal ∩ country:    $overlapMC (ожидаемо 0)');
  print('easy ∩ country:     $overlapEC (ожидаемо 0)');

  // Жанры треков в выборке metal — через карточки (span с жанром).
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse/genre/metal-rock'),
      headers: {'User-Agent': ua});
  final spans = RegExp(r'class="detail-description"[^>]*>([^<]+)<')
      .allMatches(r.body)
      .map((m) => m.group(1)!)
      .toSet()
      .toList();
  print('жанры в выборке metal-rock: $spans');
}
