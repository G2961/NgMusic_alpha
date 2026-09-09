// Одноразовый: размер webp-спрайтов 2024 (VP8X canvas).
import 'dart:io';
import 'dart:typed_data';

void main() {
  for (final p in [
    'build/ng2024_unpack/Featured_Audio/star-score-2.webp',
    'build/ng2024_unpack/Featured_Audio/playback-buttons.webp',
  ]) {
    final b = Uint8List.fromList(File(p).readAsBytesSync());
    final i = _find(b, 'VP8X'.codeUnits);
    if (i > 0) {
      final w = 1 +
          (b[i + 6] | (b[i + 7] << 8) | (b[i + 8] << 16)) & 0xFFFFFF;
      final h = 1 +
          (b[i + 9] | (b[i + 10] << 8) | (b[i + 11] << 16)) & 0xFFFFFF;
      print('$p: ${w}x$h');
    } else {
      print('$p: VP8X не найден');
    }
  }
}

int _find(Uint8List b, List<int> pattern) {
  for (var i = 12; i < b.length - pattern.length; i++) {
    var ok = true;
    for (var j = 0; j < pattern.length; j++) {
      if (b[i + j] != pattern[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}
