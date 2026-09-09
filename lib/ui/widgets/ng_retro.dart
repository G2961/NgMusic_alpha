import 'package:flutter/material.dart';

import '../theme/ng_theme.dart';

/// Виджеты, повторяющие вёрстку Newgrounds 2015.
///
/// Соответствие CSS → Flutter:
///   #main>div.fatcol>div  → [NgPod]
///   div.podtop            → [NgPodTop]
///   div.podbot            → рисуется внутри [NgPod]
///   table.audiolist tr    → [NgListRow] / [NgAudioRow]
///   div.podtop div a      → [NgPlateLink]
///   button                → [NgButton]
///   hr                    → [NgHr]
///   .ngp-seek             → [NgStripedBar]

// ── Под ───────────────────────────────────────────────────────────────────────

/// Блок контента 2015: рамка 4px, текстурная шапка, полоска-донышко.
class NgPod extends StatelessWidget {
  /// Имя иконки из спрайта `h2-all.png` (см. [NgTex.h2]), например `audio`.
  final String? icon;
  final String? title;

  /// Правый угол шапки — обычно [NgPlateLink] («More New Audio »»).
  final Widget? action;
  final Widget child;
  final NgSkin skin;

  /// `.podcontent { padding: 21px 11px 11px 11px }`, но списки живут без отступов.
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// Под растягивается на всю доступную высоту, а контент скроллится внутри —
  /// шапка пода остаётся на месте (единственная уступка мобильной сетке).
  final bool fill;

  const NgPod({
    super.key,
    this.icon,
    this.title,
    this.action,
    this.skin = NgSkin.gold,
    this.padding = const EdgeInsets.fromLTRB(11, 15, 11, 11),
    this.margin = const EdgeInsets.only(bottom: 10),
    required this.child,
  }) : fill = false;

  /// Вариант для таблиц: контент без внутренних отступов.
  const NgPod.list({
    super.key,
    this.icon,
    this.title,
    this.action,
    this.skin = NgSkin.gold,
    this.margin = const EdgeInsets.only(bottom: 10),
    required this.child,
  })  : padding = EdgeInsets.zero,
        fill = false;

  /// Под на всю высоту экрана со скроллящимся списком внутри.
  const NgPod.fill({
    super.key,
    this.icon,
    this.title,
    this.action,
    this.skin = NgSkin.gold,
    this.margin = EdgeInsets.zero,
    required this.child,
  })  : padding = EdgeInsets.zero,
        fill = true;

  @override
  Widget build(BuildContext context) {
    final hasHead = title != null;
    final content = Padding(padding: padding, child: child);
    // 2024: pod — плоский тёмный корпус, скругление 4px, тонкая рамка.
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: ngPodBg,
        border: Border.fromBorderSide(BorderSide(color: ngPodBorder, width: 1)),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHead)
            NgPodTop(icon: icon, title: title!, action: action, skin: skin),
          if (fill) Expanded(child: content) else content,
        ],
      ),
    );
  }
}

/// `div.pod-head` 2024: 35px, градиентная планка
/// (rgb(78,87,94) → rgb(52,57,61) → rgb(40,43,48) → rgb(32,36,39)),
/// иконка-квадратик 29×29 со скруглением 4px на тёмной подложке.
class NgPodTop extends StatelessWidget {
  final String? icon;
  final String title;
  final Widget? action;
  final NgSkin skin;

  const NgPodTop({
    super.key,
    this.icon,
    required this.title,
    this.action,
    this.skin = NgSkin.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      padding: const EdgeInsets.only(right: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.48, 0.53, 1],
          colors: [
            Color(0xFF4E575E),
            Color(0xFF34393D),
            Color(0xFF282B30),
            Color(0xFF202427),
          ],
        ),
        border: Border(bottom: BorderSide(color: ngBlack)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 5),
          if (icon != null) ...[
            Container(
              width: 29,
              height: 29,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Color(0x80000000),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: Center(
                child: Image.asset(NgTex.h2(icon!), width: 25, height: 25),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              title,
              style: ngH2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 3),
              child: Center(child: action),
            ),
        ],
      ),
    );
  }
}

/// Разделитель 2024: тонкая линия на стыке секций пода (в 2015 был
/// градиентный перелом podbreaker). Оставлен для совместимости экранов.
class NgPodBreaker extends StatelessWidget {
  const NgPodBreaker({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(color: ngHairline),
      ),
    );
  }
}

// ── Плашка-ссылка в шапке пода ────────────────────────────────────────────────

/// Плашка-ссылка в шапке пода 2024: скруглённая кнопка 24px с тёмной
/// подложкой и оранжевым текстом (как button в pod-head).
class NgPlateLink extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const NgPlateLink({super.key, required this.label, this.onTap});

  @override
  State<NgPlateLink> createState() => _NgPlateLinkState();
}

class _NgPlateLinkState extends State<NgPlateLink> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _down ? ngGold : const Color(0x80000000),
          border: Border.all(color: ngBlack),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontFamily: 'Arial',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.0,
            color: _down ? ngInk : (enabled ? ngGold : ngDim),
          ),
        ),
      ),
    );
  }
}

// ── Кнопка ────────────────────────────────────────────────────────────────────

/// Кнопка 2024: плоская тёмная с оранжевым текстом и скруглением 4px.
class NgButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final String? icon;

  const NgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.icon,
  });

  @override
  State<NgButton> createState() => _NgButtonState();
}

class _NgButtonState extends State<NgButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: Container(
        height: 28,
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: enabled
              ? (_down ? ngGold : const Color(0xFF34393D))
              : const Color(0xFF1A1A1A),
          border: Border.all(color: ngBlack, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Image.asset(NgTex.a15(widget.icon!, dark: _down),
                  width: 15, height: 15),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.0,
                color: !enabled ? ngDim : (_down ? ngInk : ngGold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NgIconButton extends StatefulWidget {
  final String icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double padding;

  const NgIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.padding = 6,
  });

  @override
  State<NgIconButton> createState() => _NgIconButtonState();
}

class _NgIconButtonState extends State<NgIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    Widget img = Container(
      padding: EdgeInsets.all(widget.padding),
      color: _down ? ngGold : Colors.transparent,
      child: Opacity(
        opacity: widget.onTap == null ? 0.35 : 1,
        child: Image.asset(NgTex.a15(widget.icon, dark: _down),
            width: 15, height: 15),
      ),
    );
    if (widget.tooltip != null) {
      img = Tooltip(message: widget.tooltip!, child: img);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap,
      child: img,
    );
  }
}

// ── Строки списка ─────────────────────────────────────────────────────────────

/// `table.audiolist tr` / `tr.alt` — чередование фона по индексу.
class NgListRow extends StatelessWidget {
  final int index;
  final Widget child;
  final VoidCallback? onTap;
  final NgSkin skin;
  final bool highlight;

  const NgListRow({
    super.key,
    required this.index,
    required this.child,
    this.onTap,
    this.skin = NgSkin.gold,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? skin.podtopFill
        : (index.isOdd ? skin.rowAlt : Colors.transparent);
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        splashColor: skin.podtopFill,
        highlightColor: skin.rowAlt,
        child: child,
      ),
    );
  }
}

/// Строка `a.item-audiosubmission` 2024: иконка 60×60 с PLAY-оверлеем,
/// заголовок + «by Автор» в одну строку, описание, справа — звёзды
/// (star-score-2.webp) и мета-колонка «Song / Жанр / N Views» с тонкой
/// левой границей.
class NgAudioRow extends StatelessWidget {
  final int index;
  final String iconUrl;
  final String title;
  final String genre;
  final String artist;
  final VoidCallback? onTap;
  final VoidCallback? onArtistTap;
  final Widget? trailing;

  /// Текущий трек (подсветка строки).
  final bool playing;

  /// Текущий трек на паузе: оверлей показывает play без затемнения.
  final bool paused;
  final NgSkin skin;

  const NgAudioRow({
    super.key,
    required this.index,
    required this.iconUrl,
    required this.title,
    required this.genre,
    required this.artist,
    this.onTap,
    this.onArtistTap,
    this.trailing,
    this.playing = false,
    this.paused = false,
    this.skin = NgSkin.gold,
  });

  @override
  Widget build(BuildContext context) {
    return NgListRow(
      index: index,
      onTap: onTap,
      skin: skin,
      highlight: playing,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            // Иконка-диск 60×60, оверлей внутри круглой обрезки.
            SizedBox(
              width: 60,
              height: 60,
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: NgTrackIcon(url: iconUrl, size: 60, oval: false),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _PlayOverlay(state: playing
                          ? (paused ? _PlayState.paused : _PlayState.playing)
                          : _PlayState.idle),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: playing
                        ? ngLink.copyWith(color: ngWhite)
                        : ngLink.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artist.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: GestureDetector(
                        onTap: onArtistTap,
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontFamily: 'Arial',
                                fontSize: 13,
                                color: ngText),
                            children: [
                              const TextSpan(text: 'by '),
                              TextSpan(
                                text: artist,
                                style: const TextStyle(
                                  fontFamily: 'Arial',
                                  fontSize: 13,
                                  color: ngText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (genre.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        genre,
                        style: ngLabel.copyWith(color: ngText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // Мета-колонка: звёзды + счётчики, слева тонкая граница.
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: ngDimmer, width: 1),
                ),
              ),
              child: trailing ?? const SizedBox(width: 8),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlayState { idle, playing, paused }

/// Оверлей плеера на иконке трека (2024): полупрозрачная круглая подложка
/// (обрезается ClipOval родителя) и белый play/pause по центру.
class _PlayOverlay extends StatelessWidget {
  final _PlayState state;
  const _PlayOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    // Активный трек — затемнённый диск с pause; на паузе — просто play
    // без затемнения; неактивный — полупрозрачная подложка с play.
    final icon = switch (state) {
      _PlayState.playing => Icons.pause,
      _PlayState.paused || _PlayState.idle => Icons.play_arrow,
    };
    final Color? bg = switch (state) {
      _PlayState.playing || _PlayState.idle => const Color(0x73000000),
      _PlayState.paused => null,
    };
    return IgnorePointer(
      child: SizedBox(
        width: 60,
        height: 60,
        child: Container(
          color: bg,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 34,
            color: ngWhite,
            shadows: const [Shadow(color: ngBlack, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// Строка таблицы деталей сабмишена.
class NgInfoItem {
  final String label;
  final String value;

  /// Правый край строки — например [NgStars].
  final Widget? trailing;

  /// Под значением — графика второй строкой (звёзды и т.п.).
  final Widget? below;

  const NgInfoItem(this.label, this.value, {this.trailing, this.below});
}

/// `table.itemdetails` — узкая колонка подписей слева, значение справа,
/// чередование фона строк как в аудиолисте.
class NgInfoTable extends StatelessWidget {
  final List<NgInfoItem> items;
  final NgSkin skin;
  final double labelWidth;

  /// Минимальная высота строки — чтобы рамки не смотрелись плющенными.
  final double rowHeight;

  const NgInfoTable({
    super.key,
    required this.items,
    this.skin = NgSkin.gold,
    this.labelWidth = 74,
    this.rowHeight = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          NgListRow(
            index: i,
            skin: skin,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: rowHeight),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(items[i].label, style: ngLabel),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].value,
                            style:
                                const TextStyle(fontSize: 12, color: ngWhite),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (items[i].below != null) ...[
                            const SizedBox(height: 5),
                            items[i].below!,
                          ],
                        ],
                      ),
                    ),
                    if (items[i].trailing != null) items[i].trailing!,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Колонка страницы ─────────────────────────────────────────────────────

/// `#main { background: url(bg-main.gif) top center repeat-y; padding: 10px 13px }`
/// — серая колонка, на которой стоят поды. Без неё чёрные рамки подов
/// (`border: solid 4px #000`) сливаются с фоном и блоки выглядят оторванными
/// друг от друга.
///
/// Градиент — пиксели из `bg-main.gif` (970×1): темнее по краям, светлее
/// к центру. Именно градиент, а не сама гишка: она шириной под 950px-колонку
/// и на телефоне её пришлось бы резать.
class NgPageColumn extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const NgPageColumn({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(6, 8, 6, 0),
  });

  static const _gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF454242),
      Color(0xFF302D2D),
      Color(0xFF363333),
      Color(0xFF716C6C),
      Color(0xFF363333),
      Color(0xFF302D2D),
      Color(0xFF454242),
    ],
    stops: [0, 0.006, 0.03, 0.5, 0.97, 0.994, 1],
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _gradient),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ── Награды сабмишена ──────────────────────────────────────────────────────

/// Иконка награды из спрайта `ul-trophies.png`. Ключ — класс `li` со страницы
/// (`frontpage`, `daily1`…`daily5`, `weekly1`…, `monthly1`…, `review`).
/// Смещения взяты из CSS 2015: `.daily1{background-position:4px -30px}` и далее
/// шагом 35px, `.frontpage` — -590px.
class NgTrophyIcon extends StatelessWidget {
  final String kind;
  final double size;

  const NgTrophyIcon({super.key, required this.kind, this.size = 25});

  static const _offsets = {
    'daily1': 30.0,
    'daily2': 65.0,
    'daily3': 100.0,
    'daily4': 135.0,
    'daily5': 170.0,
    'weekly1': 205.0,
    'weekly2': 240.0,
    'weekly3': 275.0,
    'weekly4': 310.0,
    'weekly5': 345.0,
    'monthly1': 380.0,
    'monthly2': 415.0,
    'monthly3': 450.0,
    'monthly4': 485.0,
    'monthly5': 520.0,
    'review': 555.0,
    'frontpage': 590.0,
  };

  static bool knows(String kind) => _offsets.containsKey(kind);

  @override
  Widget build(BuildContext context) {
    // Глиф в спрайте стоит на 5px ниже начала своей ячейки — без этого
    // смещения иконка выглядит прижатой ко дну.
    final offset = (_offsets[kind] ?? _offsets['frontpage']!) + 5;
    final scale = size / 25;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(0, -offset * scale),
            child: Image.asset(
              NgTex.trophies,
              width: size,
              height: 770 * scale,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Обложка трека ─────────────────────────────────────────────────────────────

/// Обложка трека 2024: круглый диск (`item-icon` обрезается по кругу).
/// [oval] — включить круглую обрезку; дефолт без неё — квадрат (2015).
class NgTrackIcon extends StatelessWidget {
  final String url;
  final double size;
  final bool oval;

  const NgTrackIcon({super.key, required this.url, this.size = 39, this.oval = false});

  @override
  Widget build(BuildContext context) {
    final img = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        NgTex.defaultAudioIcon,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
    if (!oval) {
      return SizedBox(width: size, height: size, child: img);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: img),
    );
  }
}

// ── Разделитель ───────────────────────────────────────────────────────────────

/// `hr { height:2px; background: #000 url(podstripe.gif) }`
class NgHr extends StatelessWidget {
  final EdgeInsets margin;
  const NgHr(
      {super.key, this.margin = const EdgeInsets.symmetric(vertical: 5)});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: margin,
      decoration: const BoxDecoration(
        color: ngBlack,
        image: DecorationImage(
          image: AssetImage(NgTex.podstripe),
          alignment: Alignment.bottomCenter,
          repeat: ImageRepeat.repeatX,
          fit: BoxFit.none,
        ),
      ),
    );
  }
}

// ── Звёзды рейтинга ───────────────────────────────────────────────────────────

/// Звёзды рейтинга 2024: спрайт `star-score-2.webp` (36×72) — верхний ряд
/// пустые, нижний залитые; заливка обрезается по ширине, как
/// `div.star-score span { width: 99% }`.
class NgStars extends StatelessWidget {
  /// 0..5
  final double score;
  final double scale;

  const NgStars({super.key, required this.score, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    // 5 звёзд по 18px = ширина 90 (CSS 2024: 93.5px с полями).
    final w = 90.0 * scale;
    final h = 17.0 * scale;
    final frac = (score / 5).clamp(0.0, 1.0);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // Пустые звёзды: верхний ряд спрайта (36×18 в масштабе).
          _StarStrip(frac: 1, filled: false, w: w, h: h),
          // Залитые: нижний ряд, обрезан по доле оценки.
          if (frac > 0)
            ClipRect(
              clipper: _WidthClipper(frac),
              child: _StarStrip(frac: 1, filled: true, w: w, h: h),
            ),
        ],
      ),
    );
  }
}

/// Ряд звёзд из спрайта 36×72: тайлится по ширине.
class _StarStrip extends StatelessWidget {
  final double frac;
  final bool filled;
  final double w;
  final double h;

  const _StarStrip(
      {required this.frac, required this.filled, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      height: h,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: h,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: w,
            height: h,
            child: Image.asset(
              NgTex.starScore2024,
              fit: BoxFit.none,
              alignment: filled ? Alignment.bottomLeft : Alignment.topLeft,
              centerSlice: Rect.fromLTWH(0, filled ? 36.0 : 0.0, 36, 36),
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

class _WidthClipper extends CustomClipper<Rect> {
  final double frac;
  const _WidthClipper(this.frac);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * frac, size.height);

  @override
  bool shouldReclip(_WidthClipper old) => old.frac != frac;
}

// ── Полосатый прогресс-бар плеера ─────────────────────────────────────────────

/// `.ngp-seek-fill { repeating-linear-gradient(45deg,#fc0 0,#fc0 8px,#111 8px,#111 16px) }`
class NgStripedBar extends StatelessWidget {
  /// 0..1
  final double value;
  final double height;

  /// Буферизация/загрузка: полоски едут.
  final double phase;

  const NgStripedBar({
    super.key,
    required this.value,
    this.height = 14,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: ngBlack,
        border: Border.fromBorderSide(BorderSide(color: ngSeekBorder)),
      ),
      child: ClipRect(
        child: CustomPaint(
          painter: _StripePainter(value.clamp(0.0, 1.0), phase),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final double value;
  final double phase;
  const _StripePainter(this.value, this.phase);

  static const _band = 8.0; // ширина полосы из CSS

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * value;
    if (w <= 0) return;
    canvas.clipRect(Rect.fromLTWH(0, 0, w, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, size.height), Paint()..color = ngPlayerStripe);

    final paint = Paint()..color = ngPlayerYellow;
    // 45°: смещаем каждую полосу на высоту, получая диагональ
    const step = _band * 2;
    final start = -size.height - (phase % step);
    for (double x = start; x < w + size.height; x += step) {
      final p = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + _band, size.height)
        ..lineTo(x + _band + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.value != value || old.phase != phase;
}

// ── Поле ввода ────────────────────────────────────────────────────────────────

/// `input[type=text]` 2015: светлая золотистая плашка с тёмным текстом.
class NgTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final Widget? suffix;

  const NgTextField({
    super.key,
    required this.controller,
    this.hint,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFE0C070),
        border: Border.fromBorderSide(BorderSide(color: ngBlack)),
        image: DecorationImage(
          image: AssetImage(NgTex.input),
          repeat: ImageRepeat.repeatX,
          fit: BoxFit.fitHeight,
          alignment: Alignment.centerLeft,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscure,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                cursorColor: ngInk,
                cursorWidth: 1,
                style: const TextStyle(
                    color: Color(0xFF1B1006), fontSize: 12, height: 1.2),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(
                      color: Color(0xFF7A5A20), fontSize: 12, height: 1.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                ),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

// ── Серая колонка страницы ────────────────────────────────────────────────────
// ── Пустое состояние / ошибка / загрузка в стиле пода ─────────────────────────

class NgNotice extends StatelessWidget {
  final String text;
  final String? icon;
  final Widget? action;

  const NgNotice({super.key, required this.text, this.icon, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Image.asset(NgTex.h2(icon!), width: 31, height: 31),
            ),
          Text(text, textAlign: TextAlign.center, style: ngBody),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

// ── Секция-аккордеон внутри пода ──────────────────────────────────────────────

/// `table.audiolist th` в роли заголовка-кнопки: тёмная полоска
/// с подписью группы строк; клик сворачивает содержимое.
///
/// [count] рисуется справа, чтобы было видно размер свёрнутой группы.
class NgSectionHead extends StatelessWidget {
  final String label;
  final String icon;
  final int? count;
  final bool collapsed;
  final VoidCallback? onTap;

  const NgSectionHead({
    super.key,
    required this.label,
    required this.icon,
    this.count,
    this.collapsed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: ngBlack,
          border: Border(
            top: BorderSide(color: ngHairline),
            bottom: BorderSide(color: ngHairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Image.asset(NgTex.h2(icon), width: 15, height: 15),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: ngLabel.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('($count)', style: ngLabel),
            ],
            const Spacer(),
            if (onTap != null)
              // Спрайтовые collapse/expand на 15×15 неразличимы (один и тот же
              // крестик). Шеврон-стрелка: вправо = свёрнуто, вниз = развёрнуто.
              AnimatedRotation(
                turns: collapsed ? 0 : 0.25,
                duration: const Duration(milliseconds: 150),
                child: Image.asset(
                  NgTex.a15('arrow-right'),
                  width: 15,
                  height: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Группа строк со сворачиваемым заголовком.
class NgSection extends StatelessWidget {
  final String label;
  final String icon;
  final int? count;
  final bool collapsed;
  final VoidCallback? onToggle;
  final List<Widget> children;

  const NgSection({
    super.key,
    required this.label,
    required this.icon,
    required this.children,
    this.count,
    this.collapsed = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NgSectionHead(
          label: label,
          icon: icon,
          count: count,
          collapsed: collapsed,
          onTap: onToggle,
        ),
        // Свёрнутое состояние — пустой второй ребёнок: AnimatedCrossFade
        // держит оба в дереве, но строки не занимают места.
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
          crossFadeState:
              collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Полосатый индикатор загрузки — те же полоски, только бегут.
class NgLoading extends StatefulWidget {
  final double width;
  const NgLoading({super.key, this.width = 120});

  @override
  State<NgLoading> createState() => _NgLoadingState();
}

class _NgLoadingState extends State<NgLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: SizedBox(
          width: widget.width,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => NgStripedBar(
              value: 1,
              height: 10,
              phase: -_c.value * 16,
            ),
          ),
        ),
      ),
    );
  }
}