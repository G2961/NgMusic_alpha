// Разведка: как NG отдаёт и принимает отзывы к аудио.
// Запуск: dart run tools/review_probe.dart
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> headers(String cookie) => {
      'User-Agent': ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cookie': cookie,
    };

void dumpMatches(String label, String body, RegExp re, {int max = 8}) {
  final ms = re.allMatches(body).take(max).toList();
  print('--- $label (${ms.length}) ---');
  for (final m in ms) {
    print(m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim());
  }
}

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args.first : '1372317';
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final page = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/listen/$id'),
      headers: headers(cookie));
  final b = page.body;
  print('listen/$id -> ${page.statusCode} len=${b.length} '
      'user=${RegExp(r"PHP\.set\('activeuser'").hasMatch(b) ? "IN" : "OUT"}');

  dumpMatches('initReview / review js', b,
      RegExp(r'ngutils\.\w*[Rr]eview\w*\([^)]*\)|initReview\w*\([^)]*\)'));
  dumpMatches('review form action', b,
      RegExp(r'<form[^>]*action="[^"]*review[^"]*"[^>]*>', caseSensitive: false));
  dumpMatches('review save/post urls', b,
      RegExp(r'/(reviews?|review)/[a-z_]+(/\d+)*', caseSensitive: false));
  dumpMatches('data-review / component', b,
      RegExp(r'(data-review-[a-z]+="[^"]*"|component=["\x27][^"\x27]*[Rr]eview[^"\x27]*)'));
  dumpMatches('votebar/uek', b,
      RegExp(r"PHP\.set\('uek'[^)]*\)|/content/vote/\d+/\d+"));

  // Страница отзывов (portalId=3 — аудио).
  final rev = await http.get(
      Uri.parse('https://www.newgrounds.com/reviews/portal/$id/3/date/1'),
      headers: headers(cookie));
  print('\nreviews/portal/$id/3/date/1 -> ${rev.statusCode} len=${rev.body.length}');
  dumpMatches('review cards', rev.body,
      RegExp(r'<div\s+class="pod-body review"[\s\S]{0,120}?data-review-id="\d+">'),
      max: 3);

  // Поля формы создания отзыва: <form action="/reviews/create/{id}/3">…
  final formM = RegExp(
          r'<form[^>]*action="/reviews/create/[^"]*"[\s\S]*?</form>')
      .firstMatch(b);
  print('\n--- create-review form ---');
  if (formM != null) {
    final form = formM.group(0)!;
    for (final m in formM
        .group(0)!
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .split('<')) {
      if (RegExp(r'^(input|textarea|select|button|form|option)')
          .hasMatch(m.trim())) {
        print('<$m');
      }
    }
    print('form len=${form.length}');
  } else {
    print('нет формы (гость/уже писал?)');
  }
}
