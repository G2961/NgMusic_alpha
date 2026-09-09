// Диагностика: сравниваем ответ Newgrounds для разных наборов заголовков.
// Запуск: dart run tools/http_probe.dart
import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

const url = 'https://www.newgrounds.com/audio/featured';

Future<void> probe(String name, Map<String, String> headers) async {
  try {
    final r = await http.get(Uri.parse(url), headers: headers);
    final server = r.headers['server'] ?? '-';
    final cf = r.headers['cf-mitigated'] ?? r.headers['cf-ray'] ?? '-';
    final snippet = r.body.length > 160 ? r.body.substring(0, 160) : r.body;
    print('$name -> ${r.statusCode} (server=$server cf=$cf len=${r.body.length})');
    if (r.statusCode != 200) print('    ${snippet.replaceAll('\n', ' ')}');
  } catch (e) {
    print('$name -> EXCEPTION $e');
  }
}

Future<void> main() async {
  // 1. Как сейчас в приложении (_connect).
  await probe('app-current', {
    'User-Agent': ua,
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  });

  // 2. Совсем без заголовков (дефолт Dart).
  await probe('bare', const {});

  // 3. Полный набор «как Chrome».
  await probe('chrome-like', {
    'User-Agent': ua,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate',
    'Upgrade-Insecure-Requests': '1',
    'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  });

  // 4. Через HttpClient напрямую (тот же TLS, но без пакета http).
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', ua);
    final resp = await req.close();
    print('dart-httpclient -> ${resp.statusCode}');
    await resp.drain();
    client.close();
  } catch (e) {
    print('dart-httpclient -> EXCEPTION $e');
  }
}
