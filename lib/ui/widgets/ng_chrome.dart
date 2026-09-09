import 'package:flutter/material.dart';

import '../theme/ng_theme.dart';

/// Шапка и навигация сайта Newgrounds 2015, сжатые под телефон.
///
/// `.sitelinks` (чёрная полоса с поиском) → [NgSearchBar]
/// `.header .navigation` (логотип)        → [NgLogoBar]
/// `.navbar` (плашки порталов)            → [NgNavPlates]

/// Акцентные цвета порталов из `ng_publish.css`
/// (`body.<skin> #footer .navigation dd span { border-color: … }`).
class NgAccent {
  static const orange = Color(0xFFE15F20); // дефолтный (gold) скин
  static const blue = Color(0xFF3A94E0); // games
  static const red = Color(0xFFF74040); // movies
  static const green = Color(0xFF60B136); // audio
  static const pink = Color(0xFFEB4FA2); // art
  static const aqua = Color(0xFF26B28C);
  static const purple = Color(0xFFC767E5);
  static const gray = Color(0xFF8698A2);
}

/// Шапка 2024: логотип слева, поиск по центру, юзер справа — всё в одной
/// строке (в 2024 sitelinks и header слиты). Поиск — тёмное поле
/// (rgb(40,43,48), радиус 4) с круглой лупой.
class NgSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onClear;
  final bool searching;

  const NgSearchBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.focusNode,
    this.onClear,
    this.searching = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: ngBlack,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF282B30),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: ngHairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search,
                      size: 16, color: ngDim),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: onSubmit,
                      onChanged: (v) {
                        if (v.isEmpty) onClear?.call();
                      },
                      cursorColor: ngGold,
                      style: const TextStyle(
                          fontFamily: 'Arial',
                          color: ngText,
                          fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search Audio',
                        hintStyle: const TextStyle(
                            fontFamily: 'Arial',
                            color: ngDim,
                            fontSize: 13),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (searching)
                    GestureDetector(
                      onTap: () {
                        controller.clear();
                        onClear?.call();
                        focusNode?.unfocus();
                      },
                      child: const Icon(Icons.close,
                          size: 16, color: ngDim),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ChromeButton(label: 'Search', onPressed: () => onSubmit(controller.text)),
        ],
      ),
    );
  }
}

/// Кнопка шапки 2024: плоская серо-градиентная плашка с оранжевым текстом
/// (`button { background: linear-gradient(#34393D 60%, #4E575E 70%) }`).
class _ChromeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _ChromeButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.6, 0.7, 1],
            colors: [
              Color(0xFF34393D),
              Color(0xFF34393D),
              Color(0xFF4E575E),
              Color(0xFF4E575E),
            ],
          ),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFF34393D), width: 2)),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Arial',
            color: ngGold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Логотип-строка 2024: тоньше (44px), без рамки, юзер справа с аватаром
/// в тёмном кружке.
class NgLogoBar extends StatelessWidget {
  final String? username;
  final String? avatarUrl;
  final VoidCallback onUserTap;

  const NgLogoBar({
    super.key,
    this.username,
    this.avatarUrl,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: ngBlack,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Image.asset(NgTex.logo, height: 32, fit: BoxFit.contain),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onUserTap,
            child: username == null
                ? const Text('Login / Sign Up',
                    style: TextStyle(
                        fontFamily: 'Arial',
                        color: ngGold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold))
                : Row(
                    children: [
                      Text(username!,
                          style: const TextStyle(
                              fontFamily: 'Arial',
                              color: ngGold,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      _Avatar(url: avatarUrl),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    // Аватарки 2015 — квадратные, в рамке 1px, без скруглений.
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: ngBrown,
        border: Border.fromBorderSide(BorderSide(color: ngGold)),
      ),
      child: url == null || url!.isEmpty
          ? Image.asset(NgTex.h2('user'), width: 20, height: 20)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Image.asset(NgTex.h2('user'), width: 20, height: 20),
            ),
    );
  }
}

/// `nav.header-nav-buttons` 2024: плоские пункты навигации, белый текст,
/// цветная полоска 2px снизу у активного. В портале NG 2024 навбар
/// горизонтальный с градиентной подсветкой при наведении.
class NgNavPlate extends StatelessWidget {
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const NgNavPlate({
    super.key,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: ngBlack,
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : const Color(0xFFFFFFFF),
                width: 2,
              ),
            ),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.0),
                      accent.withValues(alpha: 0.32),
                    ],
                    stops: const [0.66, 1],
                  )
                : null,
          ),
          alignment: Alignment.center,
          // Высота пункта 40px: 15px текст с межстрочным 1.6 (24px) +
          // 2px нижняя полоса — хвосты букв (p, y) не срезаются.
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 15,
              height: 1.6,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: ngWhite,
              shadows: const [
                Shadow(color: Color(0x80000000), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Плоский пункт нижней навигации 2024: цветная полоска 3px сверху у
/// активного, белый текст; фон приглушённый.
class _NavButton extends StatelessWidget {
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

  IconData _iconFor(String name) {
    switch (name) {
      case 'audio':
        return Icons.audio_file;
      case 'list':
        return Icons.queue_music;
      case 'user':
        return Icons.person_outline;
      default:
        return Icons.circle;
    }
  }

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
}

/// Нижняя навигация приложения (2024: плоская).
///
/// Раньше кнопки были почти чёрными (плоский градиент #1a1717→#080606), и над
/// иконками висела тёмная полоса, которая резала глаз. Теперь у каждой кнопки
/// такой же стеклянный корпус, как у плашек навбара ([NgNavPlate]): светлый
/// блик сверху, объёмный градиент и цветная полоса портала снизу. Чёрного
/// поля над кнопками не осталось.
/// Плоская nav-полоса 2024: пункты-плашки в одну строку 34px,
/// без рамок и 3D-эффектов — активный с тонкой градиентной подсветкой.
class NgNavPlates extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;
  final List<Color>? accents;

  static const _accents = [
    NgAccent.orange,
    NgAccent.blue,
    NgAccent.red,
    NgAccent.green,
    NgAccent.pink,
    NgAccent.purple,
  ];

  const NgNavPlates({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelect,
    this.accents,
  });

  @override
  Widget build(BuildContext context) {
    final palette = accents ?? _accents;
    return Container(
      height: 40,
      color: ngBlack,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            NgNavPlate(
              label: labels[i],
              accent: palette[i % palette.length],
              selected: i == index,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class NgBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    ('audio', 'Audio', NgAccent.green),
    ('list', 'Library', NgAccent.blue),
    ('user', 'Account', NgAccent.orange),
  ];

  const NgBottomNav({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ngBlack,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavButton(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  accent: _items[i].$3,
                  selected: i == index,
                  last: i == _items.length - 1,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Подвал `#footer` был тут раньше (полосатая лента + копирайт с танком).
/// Убран: на телефоне он только ел высоту списка и мешался под плеером.
