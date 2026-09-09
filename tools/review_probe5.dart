// Разведка v5: точная структура МОЕЙ карточки отзыва на странице трека
// (кнопки edit/delete, форма), плюс блок «your vote» на странице трека.
// Запуск: dart run tools/review_probe5.dart [trackId]
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> headers(String cookie) => {
      'User-Agent': ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cookie': cookie,
    };

Future<void> main(List<String> args) async {
  final trackId = args.isNotEmpty ? args.first : '1615369';
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final b = (await http.get(
          Uri.parse('https://www.newgrounds.com/audio/listen/$trackId'),
          headers: headers(cookie)))
      .body;

  // Полный блок своей карточки: от review_19684145 до закрывающей review-foot.
  final start = b.indexOf('data-review-id="19684145"');
  if (start < 0) {
    print('свой отзыв не найден на странице трека');
    return;
  }
  final from = b.lastIndexOf('<div', start);
  final seg = b.substring(from, from + 14000);
  final endM = RegExp(r'<div class="review-foot[\s\S]*?</div>\s*</div>').firstMatch(seg);
  final mine = seg.substring(0, endM?.end ?? 12000);
  print('=== MY REVIEW CARD ===');
  print(mine.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' '));
}
