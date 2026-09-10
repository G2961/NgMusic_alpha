import 'package:flutter/material.dart';

/// Палитра и формы Newgrounds 2024 (снимки web.archive в assets/ng2024).
///
/// Все значения — из декодированного `ng2024.css` (см. build/ng2024_readable),
/// в комментариях исходный селектор. Формулы то же, что в 2015-теме,
/// поэтому весь старый код компилируется без переименований: редизайн
/// идёт заменой значений, а не переписыванием экранов.
// ── Базовые цвета ─────────────────────────────────────────────────────────────

const ngBlack = Color(0xFF000000); // body { background-color: rgb(0,0,0) }
const ngPodBg = Color(0xFF0F0B0C); // div.pod-body { background-color: rgb(15,11,12) }
const ngPodBorder = Color(0xFF000000); // div.pod-body { border: 1px solid #000 }
const ngPodBotBorder = Color(0xFF282B30); // ножка пода — тон грани按钮
const ngRowAlt = Color(0xFF191315); // чередование строк itemlist
const ngMainCol = Color(0xFF0F0B0C); // фон колонки = фон пода 2024

const ngGold = Color(0xFFFDA238); // ссылки/кнопки: rgb(253,162,56)
const ngText = Color(0xFFC9BEBE); // body color: rgb(201,190,190)
const ngWhite = Color(0xFFFFFFFF);
const ngDim = Color(0xFF7D7575); // span.detail-title: rgb(125,117,117)
const ngDimmer = Color(0xFF5A5454); // border-left meta: rgb(90,84,84)
const ngInk = Color(0xFF0F0B0C); // текст на оранжевом фоне
const ngHairline = Color(0xFF282B30); // button border: rgb(40,43,48)

const ngBrown = Color(0xFF34393D); // pod-head градиент, средний тон
const ngBrownMid = Color(0xFF4E575E); // pod-head градиент, верхний тон
const ngOrange = Color(0xFFFDA238);
const ngOrangeDeep = Color(0xFF9D4F18);
const ngRed = Color(0xFFF62F36); // movies-акцент: rgb(246,47,54)
const ngGreen = Color(0xFF47B32A); // audio-акцент: rgb(71,179,42)
const ngPodGreen = Color(0xFF191919); // плоский тёмный (скины 2024 не текстурные)
const ngRowAltGreen = Color(0xFF16181A);

// ── Плеер (страница трека 2024: waveform + кнопки) ───────────────────────────

const ngPlayerYellow = Color(0xFFFDA238); // акцент плеера — золотой NG 2024 (был зелёный #67D539)
const ngPlayerStripe = Color(0xFF1E2422);
const ngPlayerBarTop = Color(0xFF1A1618);
const ngPlayerBarBot = Color(0xFF0F0B0C);
const ngSeekBorder = Color(0xFF282B30);
const ngVizTop = Color(0xFF16211A);
const ngVizMid = Color(0xFF101812);
const ngVizBot = Color(0xFF0A0810);

// ── Пути к текстурам ─────────────────────────────────────────────────────────

class NgTex {
  // Текстуры 2015 оставлены: где 2024 плоский, они не используются.
  static const podtopGold = 'assets/ng2015/tex/podtop-gold.jpg';
  static const podtopGreen = 'assets/ng2015/tex/podtop-green.jpg';
  static const podtopBlue = 'assets/ng2015/tex/podtop-blue.jpg';
  static const podtopRed = 'assets/ng2015/tex/podtop-red.jpg';
  static const podtopPink = 'assets/ng2015/tex/podtop-pink.jpg';
  static const podBody = 'assets/ng2015/tex/pod-body.jpg';
  static const podbreaker = 'assets/ng2015/tex/podbreaker.jpg';
  static const podstripe = 'assets/ng2015/tex/podstripe.png';
  static const mainColumn = 'assets/ng2015/tex/body-gold.png';
  static const linkPlate = 'assets/ng2015/tex/link-plate.png';
  static const linkPlateHover = 'assets/ng2015/tex/link-plate-hover.png';
  static const buttonNormal = 'assets/ng2015/tex/button-normal.png';
  static const buttonHover = 'assets/ng2015/tex/button-hover.png';
  static const buttonDisabled = 'assets/ng2015/tex/button-disabled.png';
  static const input = 'assets/ng2015/tex/input-gold.jpg';

  static const navbarPlates = 'assets/ng2015/tex/navbar.jpg';
  static const navTop = 'assets/ng2015/tex/nav-top.png';
  static const footerStripes = 'assets/ng2015/tex/footer-stripes.png';

  static const logo = 'assets/ng2015/logo-ngmusic.png';
  static const logoNg2015 = 'assets/ng2015/logo.png';

  /// Лого шапки 2024: танк + «NEWGROUNDS AUDIO PORTAL» (assets/header_logo.png).
  static const logoHeader2024 = 'assets/header_logo.png';
  static const logoTiny = 'assets/ng2015/logo-tiny.png';
  static const defaultAudioIcon = 'assets/ng2015/icon-audio-default.png';
  static const starsEmpty = 'assets/ng2015/stars-empty.png';
  static const starsFull = 'assets/ng2015/stars-full.png';

  static const trophies = 'assets/ng2015/ul-trophies.png';

  /// Звёзды рейтинга 2024 — спрайт 36×72 (пустые сверху, залитые снизу).
  static const starScore2024 = 'assets/ng2024/sprites/star-score.webp';

  /// Звёзды-кнопки голосования 2024 — спрайт 150×666 (одна звезда 150×134,
  /// 5 состояний: hover/idle/checked/blam, @2x).
  static const starSelect2024 = 'assets/ng2024/sprites/star-select-2.webp';

  /// Иконки настроения votebar 2024 («Steve reacts») — 210×2035, 11 кадров
  /// по 185px (@2x), кадр N = голос N (0..10).
  static const steveReact2024 = 'assets/ng2024/sprites/SteveReact4.webp';

  /// Кнопки плеера 2024 — спрайт 200×100: play слева (64×64), pause справа.
  static const playbackButtons2024 =
      'assets/ng2024/sprites/playback-buttons.webp';

  static String h2(String name) => 'assets/ng2015/h2/$name.png';

  static String a15(String name, {bool dark = false}) =>
      'assets/ng2015/a15/$name${dark ? '-dark' : ''}.png';
}

// ── Типографика ──────────────────────────────────────────────────────────────

/// 2024 использует Arial; Pakenham остаётся только для особых мест.
const ngHeaderFont = 'Pakenham';

const ngH2 = TextStyle(
  fontFamily: 'Arial',
  fontSize: 17,
  height: 1.2,
  color: ngWhite,
  fontWeight: FontWeight.w500,
);

const ngH3 = TextStyle(
  fontFamily: 'Arial',
  fontSize: 14,
  fontStyle: FontStyle.normal,
  fontWeight: FontWeight.bold,
  color: ngWhite,
);

const ngLink = TextStyle(
  fontFamily: 'Arial',
  fontSize: 13,
  fontWeight: FontWeight.normal,
  color: ngGold,
);

const ngBody =
    TextStyle(fontFamily: 'Arial', fontSize: 13, color: ngText);
const ngBodySmall =
    TextStyle(fontFamily: 'Arial', fontSize: 12, color: ngText);
const ngLabel =
    TextStyle(fontFamily: 'Arial', fontSize: 12, color: ngDim);

// ── Скины подов ──────────────────────────────────────────────────────────────

enum NgSkin { gold, green, blue, red, pink }

extension NgSkinX on NgSkin {
  // В 2024 шапки подов без текстур — плоский градиент.
  String get podtop => switch (this) {
        NgSkin.gold => NgTex.podtopGold,
        NgSkin.green => NgTex.podtopGold,
        NgSkin.blue => NgTex.podtopBlue,
        NgSkin.red => NgTex.podtopRed,
        NgSkin.pink => NgTex.podtopPink,
      };

  Color get podtopFill => switch (this) {
        NgSkin.gold => ngBrown,
        NgSkin.green => ngBrown,
        NgSkin.blue => ngBrown,
        NgSkin.red => ngBrown,
        NgSkin.pink => ngBrown,
      };

  Color get rowAlt => ngRowAlt;
}

// ── ThemeData ────────────────────────────────────────────────────────────────

final ngTheme = ThemeData(
  colorScheme: const ColorScheme.dark(
    primary: ngGold,
    secondary: ngOrange,
    surface: ngPodBg,
    onSurface: ngText,
    onPrimary: ngInk,
    error: ngRed,
  ),
  scaffoldBackgroundColor: ngBlack,
  canvasColor: ngBlack,
  appBarTheme: const AppBarTheme(
    backgroundColor: ngPodBg,
    foregroundColor: ngWhite,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: ngH2,
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: ngPlayerYellow,
    inactiveTrackColor: ngBlack,
    thumbColor: ngPlayerYellow,
    overlayColor: ngPlayerYellow.withValues(alpha: 0.2),
    trackHeight: 12,
    trackShape: const RectangularSliderTrackShape(),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: ngGold,
    linearTrackColor: ngBlack,
  ),
  dividerTheme: const DividerThemeData(color: ngHairline, thickness: 1),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ngGold,
      shape: const RoundedRectangleBorder(),
    ),
  ),
  tooltipTheme: const TooltipThemeData(
    decoration: BoxDecoration(color: ngGold),
    textStyle: TextStyle(
        fontFamily: 'Arial', color: ngInk, fontSize: 11),
  ),
  useMaterial3: true,
);

// ── Совместимость со старым кодом ────────────────────────────────────────────

const cBg = ngBlack;
const cSurface = ngPodBg;
const cSurface2 = ngRowAlt;
const cSurface3 = ngBrown;
const cPrimary = ngGold;
const cPrimary2 = ngBrownMid;
const cAccent = ngOrange;
const cPink = ngOrange;
const cTextPri = ngWhite;
const cTextSec = ngText;
const cTextDim = ngDim;
const cDivider = ngHairline;
const cOnPrimary = ngInk;

const ngBodyBg = ngPodBg;
const ngBodyText = ngText;
const ngMuted = ngDim;
const ngMutedDark = ngDimmer;
const ngGoldDark = ngBrownMid;
const ngGoldInput = ngBrown;
const ngGoldHover = ngWhite;
const ngOrangeBdr = ngOrange;
const ngDeep = ngPodBg;
const ngBgDeep = ngPodBg;
const ngBgDark = ngBlack;
const ngBgCard = ngPodBg;
const ngBgElevated = ngRowAlt;
const ngBorder = ngHairline;
const ngBorderLight = ngBrown;
const ngTextPrimary = ngWhite;
const ngTextMuted = ngText;
const ngTextDim = ngDim;
const ngAudioGreen = ngGreen;
const ngAudioGreenBg = ngPodGreen;
const ngAudioGreenBgAlt = ngRowAltGreen;
const ngAudioGreenLabel = ngPodGreen;
const ngPodHeadTop = ngBrownMid;
const ngPodHeadBot = ngBrown;
