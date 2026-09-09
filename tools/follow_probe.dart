// Диагностика подписки: почему на странице художника нет кнопки follow.
// Запуск: dart run tools/follow_probe.dart
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

void report(String name, int status, String body) {
  final loggedIn = RegExp(r"PHP\.set\('activeuser'").hasMatch(body);
  final init = body.contains('initFollowButton');
  print('$name -> $status  user=${loggedIn ? "IN " : "OUT"}  '
      'initFollowButton=${init ? "Y" : "n"}  len=${body.length}');
}

Future<void> main() async {
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // http-пакет: редиректы включены по умолчанию.
  final auto =
      await http.get(Uri.parse('https://jotacast.newgrounds.com/'), headers: headers(cookie));
  report('http auto-redirect ', auto.statusCode, auto.body);

  // Тот же запрос без авто-редиректа: видим 301 и Location.
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://jotacast.newgrounds.com/'));
  headers(cookie).forEach(req.headers.set);
  req.followRedirects = false;
  final resp = await req.close();
  print('manual         -> ${resp.statusCode}  Location=${resp.headers.value('location')}');
  await resp.drain();

  // Финальный URL с куками — так, как надо.
  final direct =
      await http.get(Uri.parse('https://jotang.newgrounds.com/'), headers: headers(cookie));
  report('final + cookie    ', direct.statusCode, direct.body);

  client.close();
}
