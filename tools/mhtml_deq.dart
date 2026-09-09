// Одноразовый: quoted-printable -> читаемый HTML (просто убираем =3D/=XX).
import 'dart:io';

void main() {
  final pairs = {
    'build/ng2024_unpack/Featured_Audio/audio.html':
        'build/ng2024_readable/audio.html',
    'build/ng2024_unpack/Windows_XP/1378989.html':
        'build/ng2024_readable/track.html',
    'build/ng2024_unpack/G2961/index.html':
        'build/ng2024_readable/user.html',
    'build/ng2024_unpack/Newgrounds_com___Everything__By_Everyone/index.html':
        'build/ng2024_readable/home.html',
  };
  Directory('build/ng2024_readable').createSync(recursive: true);
  for (final e in pairs.entries) {
    final src = File(e.key).readAsStringSync();
    final out = src
        .replaceAllMapped(RegExp(r'=([0-9A-F]{2})'),
            (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
        .replaceAll('=\r\n', '')
        .replaceAll('=\n', '');
    File(e.value).writeAsStringSync(out);
    print('${e.value}: ${out.length}');
  }
}
