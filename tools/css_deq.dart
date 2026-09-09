// Одноразовый: декодирует CSS 2024 из quoted-printable в читаемый вид.
import 'dart:io';

void main() {
  final src =
      File('build/ng2024_unpack/Featured_Audio/ng_2015.6748e868a8e45.css');
  final out = File('build/ng2024_readable/ng2024.css');
  final text = src.readAsStringSync().replaceAllMapped(
      RegExp(r'=([0-9A-F]{2})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  out.writeAsStringSync(text.replaceAll('=\r\n', '').replaceAll('=\n', ''));
  print('OK ${text.length}');
}
