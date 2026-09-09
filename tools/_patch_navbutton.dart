// Одноразовый: заменяем старый _NavButton (строки 351..469) на 2024.
import 'dart:io';

void main() {
  final p = 'lib/ui/widgets/ng_chrome.dart';
  final src = File(p).readAsStringSync();

  final start = src.indexOf('class _NavButton');
  final end = src.indexOf('/// Кнопка шапки 2024');
  if (start < 0 || end < 0) {
    print('маркеры: $start $end');
    exit(1);
  }
  final neu = '''class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color accent;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF19181C) : ngBlack,
            border: Border(
              top: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 3,
              ),
              right: BorderSide(
                color: last ? Colors.transparent : ngHairline,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconFor(icon),
                  size: 20, color: selected ? ngWhite : ngDim),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w500 : FontWeight.normal,
                    color: selected ? ngWhite : ngDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'audio':
        return Icons.audio_file;
      case 'list':
        return Icons.queue_music;
      case 'user':
        return Icons.person_outline;
      case 'search':
        return Icons.search;
      default:
        return Icons.circle;
    }
  }
}

''';

  File(p).writeAsStringSync(src.replaceRange(start, end, neu));
  print('OK');
}
