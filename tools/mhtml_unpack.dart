// Одноразовый скрипт: распаковывает MHTML-снимки 2024 в build/ng2024_unpack.
import 'dart:convert';
import 'dart:io';

void main() {
  final dir = Directory('build/ng2024_unpack');
  dir.createSync(recursive: true);

  for (final f in Directory('assets/ng2024').listSync()) {
    if (f is! File || !f.path.endsWith('.mhtml')) continue;
    final name = f.path
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.mhtml', '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final out = Directory('${dir.path}/$name')..createSync(recursive: true);
    final lines = f.readAsLinesSync();
    var boundary = '';
    for (final l in lines.take(20)) {
      final m = RegExp(r'boundary="?(.+?)"?\s*$').firstMatch(l);
      if (m != null) boundary = m.group(1)!;
    }
    if (boundary.isEmpty) {
      print('${f.path}: boundary не найден');
      continue;
    }
    final delim = '--$boundary';
    final raw = f.readAsStringSync();
    final parts = raw.split(delim).skip(1).toList();
    var count = 0;
    for (final part in parts) {
      if (part.trim() == '--' || part.isEmpty) continue;
      // Заголовки части до пустой строки.
      final headerEnd = part.indexOf(RegExp(r'(\r\n|\n)\s*(\r\n|\n)'));
      if (headerEnd < 0) continue;
      var headers = part.substring(0, headerEnd);
      var body = part.substring(headerEnd).replaceFirst(
          RegExp(r'^(\r\n|\n)+'), '');
      body = body.replaceFirst(RegExp(r'(\r\n|\n)+$'), '');

      final loc = RegExp(r'Content-Location:\s*(.+)', caseSensitive: false)
          .firstMatch(headers)
          ?.group(1)
          ?.trim();
      final enc = RegExp(r'Content-Transfer-Encoding:\s*(\S+)',
              caseSensitive: false)
          .firstMatch(headers)
          ?.group(1)
          ?.toLowerCase();
      final ctype = RegExp(r'Content-Type:\s*([^\r\n;]+)',
              caseSensitive: false)
          .firstMatch(headers)
          ?.group(1)
          ?.trim();

      if (loc == null) continue;
      var bytes;
      if (enc == 'base64') {
        // Убираем переносы.
        final b64 = body.replaceAll(RegExp(r'\s+'), '');
        try {
          bytes = base64Decode(b64);
        } catch (_) {
          continue;
        }
      } else {
        bytes = utf8.encode(body);
      }

      // Имя файла из URL: последний сегмент пути + hash.
      final uri = Uri.tryParse(loc);
      var fname = (uri?.pathSegments.isNotEmpty ?? false)
          ? uri!.pathSegments.last
          : 'index';
      if (fname.isEmpty) fname = 'index';
      if (ctype != null && ctype.contains('html') &&
          !fname.contains('.')) {
        fname = '$fname.html';
      }
      // Дедуп имён.
      var target = File('${out.path}/$fname');
      var n = 1;
      while (target.existsSync()) {
        final dot = fname.lastIndexOf('.');
        final base = dot > 0 ? fname.substring(0, dot) : fname;
        final ext = dot > 0 ? fname.substring(dot) : '';
        target = File('${out.path}/${base}_$n$ext');
        n++;
      }
      target.writeAsBytesSync(bytes);
      count++;
    }
    print('$name: $count частей');
  }
}
