import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/track.dart';
import '../../data/model/ng_review.dart';
import '../../data/repository/ng_auth.dart';
import '../../data/repository/ng_repository.dart';
import '../../services/track_downloader.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/ng_player.dart';
import '../widgets/ng_retro.dart';
import 'artist_screen.dart';
import 'login_screen.dart';

/// Аудио-портал 2015 носил зелёный скин (`body.green`) — поды здесь зелёные.
const _skin = NgSkin.gold;

/// Полноэкранный плеер: блок `.ngp` флеш-плеера 2015 (сцена + бар с транспортом)
/// плюс два пода под ним — статистика трека и автор.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final track = vm.currentTrack;
    final landscape = MediaQuery.of(context).size.width >
        MediaQuery.of(context).size.height;

    // Верхняя часть страницы. В ландшафте — как старый YouTube:
    // слева плеер, справа сверху блок автора (с подпиской), под ним
    // Credits & Info, под ним награда (Frontpaged) с датой.
    // Вся верхняя секция жёстко вписана в видимую высоту экрана:
    //   экран − статус-бар − шапка 56 − верхний паддинг 8 − зазор 6.
    // Левый плеер тянется на неё всю (обложка добирает остаток), правая
    // колонка при нехватке места равномерно сжимается (FittedBox).
    final playerBlock = _PlayerPod(vm: vm, track: track);
    final creditsBlock = track == null
        ? const NgPod(
            icon: 'audio',
            title: 'Track Info',
            skin: _skin,
            child: NgNotice(text: 'Nothing is playing.', icon: 'audio'),
          )
        : _CreditsPod(track: track);

    final Widget top;
    if (landscape && track != null) {
      // Вся верхняя секция вписана в видимую высоту:
      //   экран − статус-бар − шапка 56 − верхний паддинг 8 − зазор 6.
      // Левому плееру остаётся ровно topH (обложка добирает остаток минус бары),
      // правая колонка при переполнении скроллится — без FittedBox, который
      // пересчитывал масштаб при догрузке данных (блок «прыгал»).
      final m = MediaQuery.of(context);
      final topH =
          (m.size.height - m.padding.top - 56 - 8 - 6).clamp(180.0, m.size.height);
      top = SizedBox(
        height: topH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _PlayerPod(
                vm: vm,
                track: track,
                // Сцена = обложка + бары 92 + рамки 2; сверху под добавляет
                // шапку 36 (35+1), паддинг 8 и нижнюю границу 1. Итого 139 —
                // иначе под вылезает на пиксель за отведённую высоту.
                artHeight: topH - 139,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _AuthorPod(track: track),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          creditsBlock,
                          if (track.awards.isNotEmpty) _TrophyPod(track: track),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      top = Column(children: [
        playerBlock,
        if (track != null) ...[const SizedBox(height: 10), _AuthorPod(track: track)],
        if (track != null) creditsBlock,
      ]);
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(track: track),
            Expanded(
              // Ключ форсирует полный ребилд при смене трека, иначе в дочерних
              // виджетах остаётся старый автор/название.
              key: ValueKey(track?.id),
              // Поды стоят на серой колонке `#main`, иначе их чёрные рамки
              // сливаются с фоном и блоки ломают композицию.
              child: NgPageColumn(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 24),
                  child: Column(
                    children: [
                      top,
                      if (track != null) ...[
                        // В ландшафте трофей уже в правой колонке, под Credits.
                        if (!(landscape && track.awards.isNotEmpty))
                          if (track.awards.isNotEmpty) _TrophyPod(track: track),
                        if (track.description != null)
                          _TextPod(
                            icon: 'doc',
                            title: 'Author Comments',
                            text: track.description!,
                          ),
                        _ReviewsPod(track: track),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Диалоги в стиле пода ──────────────────────────────────────────────────────

/// Окно «нужен логин»: под с текстом и двумя кнопками 2015.
Future<void> _requireLogin(
  BuildContext context,
  NgViewModel vm,
  String message,
) async {
  final doLogin = await showDialog<bool>(
    context: context,
    barrierColor: ngBlack.withValues(alpha: 0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: NgPod(
        icon: 'user',
        title: 'Login Required',
        skin: _skin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: ngBody),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NgButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const SizedBox(width: 8),
                NgButton(
                  label: 'Log In',
                  icon: 'key',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (doLogin == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (context.mounted) await vm.fetchUser();
  }
}

void _showNgSnack(BuildContext context, String text, {bool ok = true}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text, style: const TextStyle(color: ngWhite, fontSize: 12)),
    backgroundColor: ok ? ngOrange : ngRed,
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(),
    duration: const Duration(seconds: 2),
  ));
}

// ── Шапка ─────────────────────────────────────────────────────────────────────

class _TopBar extends StatefulWidget {
  final Track? track;
  const _TopBar({this.track});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  Future<void> _onFavTap(
      BuildContext context, NgViewModel vm, LibraryViewModel lvm) async {
    if (vm.currentUser == null) {
      await _requireLogin(context, vm, 'Log in to save favorites.');
      return;
    }
    final ok = await lvm.toggleFavorite(widget.track!);
    if (!context.mounted || ok) return;
    final error = lvm.lastError;
    lvm.clearError();
    _showNgSnack(context, error ?? 'Failed to save favorite', ok: false);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: ngBlack,
        border: Border(bottom: BorderSide(color: ngHairline)),
      ),
      child: Row(
        children: [
          NgIconButton(
            icon: 'collapse',
            padding: 10,
            tooltip: 'Close player',
            onTap: () => Navigator.maybePop(context),
          ),
          // Логотип сайта в самом верху, как в шапке NG
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(NgTex.logo, height: 40, fit: BoxFit.contain),
            ),
          ),
          if (track != null) ...[
            Builder(builder: (ctx) {
              final lvm = ctx.watch<LibraryViewModel>();
              final vm = ctx.watch<NgViewModel>();
              final isFav = lvm.isFavorite(track.id);
              final syncing = lvm.isFavoriteSyncing(track.id);
              return NgIconButton(
                icon: isFav ? 'fav-on' : 'fav-add',
                padding: 9,
                tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                onTap: syncing ? null : () => _onFavTap(ctx, vm, lvm),
              );
            }),
            NgIconButton(
              icon: 'playlist',
              padding: 9,
              tooltip: 'Add to playlist',
              onTap: () => showAddToPlaylistSheet(context, track),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

// ── Под плеера ────────────────────────────────────────────────────────────

/// Шапка «иконка + название трека» и плашка «Download this song!» — точно как
/// на `/audio/listen/{id}`; внутри — блок `.ngp`.
class _PlayerPod extends StatefulWidget {
  final NgViewModel vm;
  final Track? track;

  /// Ландшафт: точная высота обложки (остаток высоты сцены минус бары).
  final double? artHeight;
  const _PlayerPod({required this.vm, this.track, this.artHeight});

  @override
  State<_PlayerPod> createState() => _PlayerPodState();
}

class _PlayerPodState extends State<_PlayerPod> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    return NgPod(
      icon: 'audio',
      title: track?.title ?? 'Audio Player',
      skin: _skin,
      padding: const EdgeInsets.all(4),
      action: track == null
          ? null
          : NgPlateLink(
              label: _downloading ? 'Downloading…' : 'Download »',
              onTap: _downloading
                  ? null
                  : () async {
                      setState(() => _downloading = true);
                      await TrackDownloader.download(track, context);
                      if (mounted) setState(() => _downloading = false);
                    },
            ),
      child: _PlayerStage(vm: widget.vm, track: track, artHeight: widget.artHeight),
    );
  }
}

// ── Блок `.ngp` ──────────────────────────────────────────────────────────────

/// Связывает [NgPlayerStage] с вьюмоделью — сама сцена о ней не знает.
class _PlayerStage extends StatelessWidget {
  final NgViewModel vm;
  final Track? track;
  final double? artHeight;
  const _PlayerStage({required this.vm, this.track, this.artHeight});

  @override
  Widget build(BuildContext context) {
    final duration = vm.duration ??
        ((track?.duration ?? 0) > 0
            ? Duration(seconds: track!.duration)
            : null);

    return NgPlayerStage(
      artUrls: track?.artworkUrls ?? const [],
      artHeight: artHeight,
      playing: vm.isPlaying,
      loading: vm.isLoadingTrack,
      position: vm.position,
      duration: duration,
      shuffle: vm.shuffle,
      repeat: vm.repeat,
      onPlayPause: track == null ? null : vm.togglePlayPause,
      onPrev: vm.hasPrev() ? vm.playPrev : null,
      onNext: vm.hasNext() ? vm.playNext : null,
      onShuffle: vm.toggleShuffle,
      onRepeat: vm.cycleRepeat,
      onSeek: vm.seekTo,
    );
  }
}

// ── Секция деталей: жанр, теги, прослушивания, звёзды, шаринг ───────────────

/// `div.contentdata` со страницы трека: слева жанр и теги, справа
/// «N Plays | N Downloads», ниже звёзды и кнопки шаринга. Цифра оценки
/// здесь не дублируется — она выше, в строке `Score`.
///
/// Живёт вторым `podcontent` внутри пода Credits & Info.
class _DetailsSection extends StatelessWidget {
  final Track track;
  const _DetailsSection({required this.track});

  @override
  Widget build(BuildContext context) {
    final score = double.tryParse(track.score ?? '') ?? 0;
    final stats = [
      if (track.listens != null) '${track.listens} Plays',
      if (track.downloads != null) '${track.downloads} Downloads',
    ].join('  |  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  track.genre.isEmpty ? 'Unknown Genre' : track.genre,
                  style: ngLink.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (stats.isNotEmpty)
                Text(stats, style: ngLabel.copyWith(color: ngText)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tags: ', style: ngLabel),
              Expanded(
                child: track.tags.isEmpty
                    ? const Text('None', style: ngLabel)
                    : Text(
                        track.tags.join(', '),
                        style: ngLink.copyWith(fontWeight: FontWeight.normal),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
          const NgHr(margin: EdgeInsets.symmetric(vertical: 6)),
          Row(
            children: [
              if (score > 0)
                NgStars(score: score)
              else
                const Text('Not rated yet', style: ngLabel),
              const Spacer(),
              _ShareButton(
                letter: 'f',
                color: const Color(0xFF3B5998),
                tooltip: 'Share on Facebook',
                url: 'https://www.facebook.com/sharer/sharer.php'
                    '?u=${Uri.encodeComponent(_trackUrl(track))}',
              ),
              const SizedBox(width: 5),
              _ShareButton(
                letter: 't',
                color: const Color(0xFF55ACEE),
                tooltip: 'Share on Twitter',
                url: 'https://twitter.com/intent/tweet'
                    '?url=${Uri.encodeComponent(_trackUrl(track))}'
                    '&text=${Uri.encodeComponent('${track.title} by ${track.artist}')}',
              ),
              const SizedBox(width: 5),
              NgIconButton(
                icon: 'link',
                padding: 5,
                tooltip: 'Open on Newgrounds',
                onTap: () => _open(_trackUrl(track)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _trackUrl(Track t) => 'https://www.newgrounds.com/audio/listen/${t.id}';

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Квадратная кнопка шаринга, как в футере сабмишена 2015.
class _ShareButton extends StatelessWidget {
  final String letter;
  final Color color;
  final String url;
  final String tooltip;

  const _ShareButton({
    required this.letter,
    required this.color,
    required this.url,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => _open(url),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: ngBlack),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: const TextStyle(
              color: ngWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Награды (Frontpaged и прочие трофеи) ──────────────────────────────────────

/// Как на странице 2015: иконка из спрайта `ul-trophies.png`, рядом название
/// награды и дата. Одна награда — под без шапки, несколько — под «Trophies»
/// со списком; в обоих случаях коробка закрывается снизу донышком пода.
class _TrophyPod extends StatelessWidget {
  final Track track;
  const _TrophyPod({required this.track});

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < track.awards.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i == track.awards.length - 1 ? 0 : 8),
            child: _TrophyRow(award: track.awards[i]),
          ),
      ],
    );

    // Один трофей — без зелёной шапки, как в макете.
    if (track.awards.length == 1) {
      return NgPod(
        skin: _skin,
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        child: rows,
      );
    }

    return NgPod(
      icon: 'badge',
      title: 'Trophies',
      skin: _skin,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      child: rows,
    );
  }
}

class _TrophyRow extends StatelessWidget {
  final TrackAward award;
  const _TrophyRow({required this.award});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NgTrophyIcon(kind: award.kind, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                award.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: ngWhite,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              if (award.date.isNotEmpty)
                Text(award.date, style: ngLink.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Текстовые поды: Licensing Terms / Author Comments ───────────────────────

class _TextPod extends StatelessWidget {
  final String icon;
  final String title;
  final String text;

  const _TextPod({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return NgPod(
      icon: icon,
      title: title,
      skin: _skin,
      child: Text(text, style: ngBody.copyWith(height: 1.45)),
    );
  }
}

// ── Credits & Info: метаданные сабмишена + секция деталей ──────────────────

class _CreditsPod extends StatelessWidget {
  final Track track;
  const _CreditsPod({required this.track});

  @override
  Widget build(BuildContext context) {
    final t = track;
    final artist = t.artist;
    final score = double.tryParse(t.score ?? '') ?? 0;

    void openProfile() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
        );

    return NgPod.list(
      icon: 'user',
      title: 'Credits & Info',
      skin: _skin,
      action: NgPlateLink(label: 'Profile »', onTap: openProfile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Первый `podcontent`: метаданные сабмишена
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CreditRow(label: 'Date', value: t.uploaded ?? '—'),
                _CreditRow(
                  label: 'File Info',
                  value: t.fileInfo ??
                      (t.duration > 0
                          ? 'Song | ${NgTimeLabel.fmt(Duration(seconds: t.duration))}'
                          : '—'),
                ),
                _CreditRow(
                  label: 'Score',
                  value: score > 0
                      ? '${score.toStringAsFixed(2)} / 5.00'
                      : 'Not rated',
                ),
                if (t.votes != null)
                  _CreditRow(label: 'Votes', value: t.votes!),
                if (t.bpm != null && t.bpm!.isNotEmpty)
                  _CreditRow(label: 'BPM', value: t.bpm!),
                _TrackIdRow(trackId: t.id),
              ],
            ),
          ),
          // Второй `podcontent` того же пода: жанр, теги, статистика, шаринг
          const NgPodBreaker(),
          _DetailsSection(track: t),
        ],
      ),
    );
  }
}

// ── Коробка автора: аватар, ник, разделитель, кнопка подписки ────────────

class _AuthorPod extends StatefulWidget {
  final Track track;
  const _AuthorPod({required this.track});

  @override
  State<_AuthorPod> createState() => _AuthorPodState();
}

class _AuthorPodState extends State<_AuthorPod> {
  bool _following = false;
  bool? _followed;

  @override
  void initState() {
    super.initState();
    _loadFollowStatus();
  }

  @override
  void didUpdateWidget(_AuthorPod old) {
    super.didUpdateWidget(old);
    if (old.track.artist != widget.track.artist) {
      _followed = null;
      _loadFollowStatus();
    }
  }

  Future<void> _loadFollowStatus() async {
    final artist = widget.track.artist;
    if (artist.isEmpty) return;
    // Статус читается только по классу `active` на кнопке favefollow;
    // null остаётся, когда определить не удалось, и кнопка не врёт.
    final status = await NgRepository().getFollowStatus(artist);
    if (mounted) setState(() => _followed = status);
  }

  Future<void> _onFollowTap(NgViewModel vm) async {
    if (vm.currentUser == null) {
      await _requireLogin(
          context, vm, 'You need to be logged in to follow artists.');
      return;
    }

    final target = !(_followed ?? false);
    setState(() => _following = true);
    final confirmed =
        await vm.setFollow(widget.track.artist.toLowerCase(), target);
    if (!mounted) return;
    final ok = confirmed == target;
    setState(() {
      _following = false;
      if (ok) _followed = target;
    });
    _showNgSnack(
      context,
      ok
          ? (target
              ? 'Now following ${widget.track.artist}!'
              : 'Unfollowed ${widget.track.artist}')
          : (target ? 'Failed to follow' : 'Failed to unfollow'),
      ok: ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final t = widget.track;
    final artist = t.artist;
    final followed = _followed == true;

    void openProfile() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
        );

    return NgPod(
      skin: _skin,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: openProfile,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: ngBlack,
                  border: Border.fromBorderSide(BorderSide(color: ngBrown)),
                ),
                child: t.authorIcon == null
                    ? Image.asset(NgTex.defaultAudioIcon, fit: BoxFit.cover)
                    : NgTrackIcon(url: t.authorIcon!, size: 32),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: openProfile,
                  child: Text(
                    artist.isEmpty ? '—' : artist,
                    style: ngLink.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: ngHairline,
            ),
            Center(
              child: NgButton(
                label: _following
                    ? '…'
                    : followed
                        ? 'Following'
                        : 'Follow',
                icon: followed ? 'check' : 'user-add',
                width: 96,
                onPressed: _following ? null : () => _onFollowTap(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ID сабмишена NG (числом, как в URL /audio/listen/…) с копированием в
/// буфер — для геометри дэш и прочих сервисов, которым нужен голый ID.
class _TrackIdRow extends StatelessWidget {
  final String trackId;
  const _TrackIdRow({required this.trackId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 58,
            child: Text('ID',
                style: TextStyle(
                    fontSize: 11, color: ngDim, fontStyle: FontStyle.italic)),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    trackId,
                    style: const TextStyle(fontSize: 12, color: ngWhite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: trackId));
                    _showNgSnack(context, 'Track ID copied');
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.copy, size: 13, color: ngGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка правой колонки `Credits & Info`: подпись курсивом, значение белым.
class _CreditRow extends StatelessWidget {
  final String label;
  final String value;
  const _CreditRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: ngDim, fontStyle: FontStyle.italic)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: ngWhite),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Отзывы и оценка ─────────────────────────────────────────────────────

/// Под отзывов: своя оценка (votebar), список отзывов с пагинацией
/// и форма написания отзыва — как на странице сабмишена 2015.
class _ReviewsPod extends StatefulWidget {
  final Track track;
  const _ReviewsPod({required this.track});

  @override
  State<_ReviewsPod> createState() => _ReviewsPodState();
}

class _ReviewsPodState extends State<_ReviewsPod> {
  static final _repo = NgRepository();
  static const _sorts = [('date', 'Date'), ('score', 'Score')];

  ReviewsPage? _page;
  String _sort = 'date';
  // Направление: false — убывание (новые сверху / высокие сверху),
  // true — возрастание. Дефолт: свежие отзывы сверху.
  bool _asc = false;
  int _pageNum = 1;
  bool _loading = false;
  String? _error;

  /// Мой отзыв (синхронизирован с NG в `_load`); null — ещё не писал.
  NgReview? _myReview;
  /// Сохранённый голос в шкале NG 0..10 (null — не голосовал).
  int? _myVote;
  /// Форма открыта (написание или правка карандашом).
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // NG сортирует только по убыванию. Для возрастания зеркалим страницы:
    // логическая страница 1 (старейшие) = последняя страница NG, развёрнутая.
    final known = _page?.pages ?? 1;
    final fetchPage = _asc ? (known - _pageNum + 1).clamp(1, known) : _pageNum;
    // Свой отзыв и голос тянем параллельно со списком чужих.
    final results = await Future.wait([
      _repo.getReviews(widget.track.id, sort: _sort, page: fetchPage),
      _repo.getMyReview(widget.track.id),
      NgAuth.getMyVote(widget.track.id),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _page = results[0] as ReviewsPage?;
      _error = _page == null ? 'Could not load reviews' : null;
      _myReview = results[1] as NgReview?;
      _myVote = results[2] as int?;
    });
  }

  /// Отправка ответа автора; при успехе дожидаемся перезагрузки отзывов,
  /// чтобы после закрытия диалога ответ уже стоял в карточке.
  Future<String?> _respond(String reviewId, String text) async {
    final err = await _repo.postResponse(reviewId, text);
    if (err == null) await _load();
    return err;
  }

  void _go(int p) {
    _pageNum = p.clamp(1, _page?.pages ?? 1);
    _load();
  }

  /// Тап по пункту сортировки: неактивный — включить ключ (убывание,
  // дефолт NG); активный — развернуть направление на месте.
  void _toggleSort(String key) {
    if (_sort == key) {
      _pageNum = 1;
      _asc = !_asc;
      _load();
    } else {
      _sort = key;
      _asc = false;
      _pageNum = 1;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    // Reply доступен только автору трека (проверка дублем на сервере NG:
    // форму /reviews/responses/create/{id} видно только владельцу).
    final canRespond = vm.currentUser != null &&
        vm.currentUser!.username.toLowerCase() ==
            widget.track.artist.toLowerCase();
    return NgPod(
      icon: 'speech',
      title: 'Reviews',
      skin: _skin,
      padding: const EdgeInsets.fromLTRB(11, 15, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Блок «Your Review»: голос + свой отзыв + карандаш ────────
          if (vm.currentUser != null) ...[
            _VoteBar(
              trackId: widget.track.id,
              savedVote: _myVote,
              onVoted: (v) => setState(() => _myVote = v),
            ),
            const SizedBox(height: 10),
            if (_editing || (_myReview == null))
              _WriteReview(
                vm: vm,
                track: widget.track,
                existing: _editing ? _myReview : null,
                stars: _myVote ?? 0,
                onCancel: _myReview != null
                    ? () => setState(() => _editing = false)
                    : null,
                onSaved: (r) => setState(() {
                  _myReview = r;
                  _editing = false;
                }),
              )
            else
              _MyReviewBlock(
                review: _myReview!,
                onEdit: () => setState(() => _editing = true),
              ),
            const SizedBox(height: 12),
          ],

          // ── Чужие отзывы ────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: Text('Loading…', style: ngLabel)),
            )
          else if (_error != null)
            Column(children: [
              Text(_error!, style: ngLabel.copyWith(color: ngWhite)),
              const SizedBox(height: 6),
              NgButton(label: 'Retry', onPressed: _load),
            ])
          else if (_page == null || _page!.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No reviews yet. Be the first!', style: ngLabel),
            )
          else ...[
            // `div.pagenav` 2024: сортировка слева, страницы справа.
            Builder(builder: (context) {
              // NG всегда отдаёт убывание (новые/высокие сверху) —
              // разворачиваем список при выборе возрастания.
              final items =
                  _asc ? _page!.items.reversed.toList() : _page!.items;
              return Column(children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // div.sort: ссылки без плашек; активная — жирная со стрелкой
                    // направления (▼ убывание / ▲ возрастание).
                    const Text('Sort By: ', style: ngLabel),
                    for (var i = 0; i < _sorts.length; i++) ...[
                      if (i > 0) const Text(' | ', style: ngLabel),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggleSort(_sorts[i].$1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sorts[i].$2,
                              style: _sort == _sorts[i].$1
                                  ? ngLabel.copyWith(
                                      color: ngGold,
                                      fontWeight: FontWeight.bold)
                                  : ngLabel,
                            ),
                            if (_sort == _sorts[i].$1)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  _asc ? '▲' : '▼',
                                  style: ngLabel.copyWith(
                                      color: ngGold, fontSize: 9),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _ReviewPager(
                            page: _page!.page, pages: _page!.pages, onGo: _go),
                      ),
                    ),
                  ],
                ),
                const NgHr(margin: EdgeInsets.symmetric(vertical: 6)),
                // Карточки разделены тонкой чертой, без рамок.
                for (var i = 0; i < items.length; i++) ...[
                  _ReviewCard(
                    review: items[i],
                    canRespond: canRespond,
                    onRespond: _respond,
                  ),
                  if (i < items.length - 1)
                    const NgHr(margin: EdgeInsets.symmetric(vertical: 4)),
                ],
                const SizedBox(height: 6),
              ]);
            }),
          ],
        ],
      ),
    );
  }
}

/// Votebar NG 2024 (мобильный эталон `Back To Life.mht`):
/// слева blam-звезда (Vote 0), затем бар из 5 звёзд (спрайт star-select-2,
/// тайл = весь файл, сжатый до 46.15×204.92; кадры по 41: hover/idle/checked/
/// idle/blam), каждая звезда — ДВЕ тап-зоны по ползвезды (голос 1..10),
/// справа — реакция Стива (SteveReact4, 11 кадров по 40, кадр = голос).
///
/// NG после голоса убирает votebar со страницы — сохранённый голос приходит
/// извне ([savedVote], звёзды 0..5) и подсвечивается золотым.
class _VoteBar extends StatefulWidget {
  final String trackId;
  final int? savedVote; // 0..5, null — ещё не голосовал
  final ValueChanged<int> onVoted;

  const _VoteBar({
    required this.trackId,
    required this.onVoted,
    this.savedVote,
  });

  @override
  State<_VoteBar> createState() => _VoteBarState();
}

class _VoteBarState extends State<_VoteBar> {
  static final _repo = NgRepository();

  int _voted = 0; // голос в шкале NG 0..10
  bool _hasVote = false; // голос реально стоит (иначе нулевая серая)
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    // savedVote — уже в шкале NG 0..10 (полузвёзды).
    _hasVote = widget.savedVote != null;
    _voted = widget.savedVote ?? 0;
  }

  @override
  void didUpdateWidget(_VoteBar old) {
    super.didUpdateWidget(old);
    if (widget.savedVote != old.savedVote) {
      _hasVote = widget.savedVote != null;
      _voted = widget.savedVote ?? 0;
    }
  }

  Future<void> _vote(int value, NgViewModel vm) async {
    if (_busy || value < 0 || value > 10) return;
    if (vm.currentUser == null) {
      await _requireLogin(context, vm, 'Log in to rate this audio.');
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    // voteTrack ждёт голос в шкале NG 0..10 (полузвёзды).
    final res = await _repo.voteTrack(widget.trackId, value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res == null) {
        _note = 'Vote failed — try again';
      } else {
        _voted = value;
        _hasVote = true;
        _note = res.waiting
            ? 'Waiting for more votes…'
            : 'You voted ${(value / 2).toStringAsFixed(value.isOdd ? 1 : 0)}!';
        // Наверх — голос в шкале NG 0..10, без округлений, иначе
        // didUpdateWidget перерисует полузвёзды как целые звёзды.
        widget.onVoted(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D0D),
        border: Border.all(color: const Color(0xFF262523)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        children: [
          Text(
            _busy
                ? 'Voting…'
                : _note ??
                    (_voted > 0
                        ? 'You Rated This ${(_voted / 2).toStringAsFixed(_voted.isOdd ? 1 : 0)}/5'
                        : 'RATE THIS SUBMISSION!'),
            style: TextStyle(
              fontFamily: ngHeaderFont,
              fontSize: 16,
              color:
                  (_note != null || _voted > 0) && !_busy ? ngGold : ngWhite,
              shadows: const [Shadow(color: ngBlack, offset: Offset(0, 1))],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Vote fairly! Haters and ass-kissers don't help anybody.",
            style: TextStyle(fontSize: 9, color: ngDim),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          _VoteStarRow(
            selected: _voted,
            hasVote: _hasVote,
            enabled: !_busy,
            onSelect: (v) => _vote(v, vm),
          ),
        ],
      ),
    );
  }
}

/// Ряд оценки: blam-звезда + бар 5 звёзд (полузвёздные тап-зоны) + Стив.
/// [selected] — голос в шкале 0..10 (полузвёзды). Тап по полузвезде N
/// даёт округлённые вверх звёзды (нечётный 7 → 4 звезды = 8 голос NG —
/// на NG-клиенте так же: label[value=7] накрывает 70% бара).
class _VoteStarRow extends StatelessWidget {
  final int selected; // 0..10 полузвёзд

  /// Голос реально стоит: иначе нулевая звезда — серая, не розовая.
  final bool hasVote;
  final bool enabled;
  final ValueChanged<int> onSelect; // 0..10 (0 — нулевая звезда)

  const _VoteStarRow({
    required this.selected,
    required this.hasVote,
    required this.onSelect,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        height: 41,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // «0 звёзд» — битая звезда: серый контур (кадр 3); розовый
            // (кадр 4) — только когда реально стоит голос 0. Размер —
            // как у звёзд бара, иначе кадр обрезается сверху.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onSelect(0) : null,
              child: SizedBox(
                width: 46.15,
                height: 41,
                child: Stack(children: [
                  Positioned.fill(
                    child: _StarTile(frame: 3),
                  ),
                  if (hasVote && selected == 0)
                    Positioned.fill(
                      child: _StarTile(frame: 4),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 2),
            // Бар: 5 звёзд по 46.15×41, каждая — две тап-зоны.
            for (var s = 0; s < 5; s++)
              SizedBox(
                width: 46.15,
                height: 41,
                child: Row(children: [
                  // Левая полузвезда: голос 2s+1 (залив ≥ 2s+1).
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onSelect(s * 2 + 1) : null,
                    child: _HalfStar(
                        left: true, gold: selected >= s * 2 + 1),
                  ),
                  // Правая: голос 2s+2.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onSelect(s * 2 + 2) : null,
                    child: _HalfStar(
                        left: false, gold: selected >= s * 2 + 2),
                  ),
                ]),
              ),
            const SizedBox(width: 6),
            // Реакция Стива: кадр = голос (0..10).
            _SteveReact(frame: selected.clamp(0, 10)),
          ],
        ),
      ),
    );
  }
}

/// Звезда из спрайта star-select-2. NG (CSS) сжимает ВЕСЬ файл
/// (150×666 @2x) в тайл 46.15×204.92 CSS-px; кадр = 41px.
/// Кадры: 0 hover, 1 idle (контур в круге), 2 checked (золотая),
/// 3 idle2 (битая — «0 звёзд»), 4 blam (розовая).
/// [w]×[h] — размер звезды (бар 46.15×41, blam 41.5×36).
class _StarTile extends StatelessWidget {
  final int frame;
  final double w;
  final double h;

  const _StarTile({required this.frame, this.w = 46.15, this.h = 41});

  @override
  Widget build(BuildContext context) {
    // Весь файл сжимается в тайл (как background-size у NG) — окно
    // по ширине = весь тайл, иначе круг-обводка звезды срезается.
    return _SpriteSlice(
      asset: NgTex.starSelect2024,
      fileW: 150,
      fileH: 666,
      tileW: 46.15,
      tileH: 204.92,
      sliceX: 0,
      sliceY: frame * 41.0,
      sliceW: 46.15,
      sliceH: 41,
      viewW: w,
      viewH: h,
    );
  }
}

/// Половина звезды бара: левая или правая половина кадра.
/// Половина звезды бара: окно 23px с клипом; через OverflowBox показывает
/// левую или правую половину целой звезды (46.15).
/// Золотая (checked), если за эту полузвезду проголосовано, иначе контур.
class _HalfStar extends StatelessWidget {
  final bool left;
  final bool gold;

  const _HalfStar({required this.left, required this.gold});

  @override
  Widget build(BuildContext context) {
    // Как в CSS NG: бар всегда залит idle-тайлом (серый круг + контур),
    // а золотая звезда кладётся ПОВЕРХ — круг остаётся виден по краям.
    Widget layer(int frame) => _StarTile(frame: frame);
    return ClipRect(
      child: SizedBox(
        width: 46.15 / 2,
        height: 41,
        child: OverflowBox(
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          minWidth: 0,
          minHeight: 0,
          maxWidth: 46.15,
          maxHeight: 41,
          child: Stack(children: [
            layer(1), // idle: круг + серый контур — всегда
            if (gold) layer(2), // checked: золотая поверх
          ]),
        ),
      ),
    );
  }
}

/// Реакция Стива (мобильный эталон): 45.4×40, спрайт SteveReact4
/// (файл 210×2035 @2x = 105×1017.5 CSS), 11 кадров по 40, кадр N = y N×40.
/// NG рисует фон «45.4054px 440px» — файл сжат до 105 CSS-ширины... нет:
/// background-size 45.4054px 440px — ширина = ширине иконки, т.е. файл
/// сжат ПО ГОРИЗОНТАЛИ с 105 до 45.4?! Тогда лица сплющены — на живом NG
/// пропорции нормальные, значит фон = 105×440÷... Сверим: 2035/2 = 1017.5
/// CSS при ширине файла 105. NG задаёт 45.4×440 — ровно 0.4324 масштаба.
/// 1017.5 × 0.4324 = 440 ✓. Т.е. файл сжат до 45.4×440, кадры по 40.
class _SteveReact extends StatelessWidget {
  final int frame; // 0..10
  const _SteveReact({required this.frame});

  @override
  Widget build(BuildContext context) {
    return _SpriteSlice(
      asset: NgTex.steveReact2024,
      fileW: 210,
      fileH: 2035,
      tileW: 45.4054,
      tileH: 440,
      sliceX: 0,
      sliceY: frame.clamp(0, 10) * 40.0,
      sliceW: 45.4054,
      sliceH: 40,
      viewW: 45.4,
      viewH: 40,
    );
  }
}

/// Вырезка из спрайта с масштабированием файла в CSS-тайл (как background-size
/// у NG). Файл (fileW×fileH файловых px) рисуется сжатым до tileW×tileH
/// CSS-px; из него показывается область (sliceX, sliceY, sliceW×sliceH);
/// виджет — viewW×viewH (по умолчанию = slice).
class _SpriteSlice extends StatelessWidget {
  final String asset;
  final double fileW, fileH;
  final double tileW, tileH;
  final double sliceX, sliceY, sliceW, sliceH;
  final double? viewW, viewH;

  const _SpriteSlice({
    required this.asset,
    required this.fileW,
    required this.fileH,
    required this.tileW,
    required this.tileH,
    required this.sliceX,
    required this.sliceY,
    required this.sliceW,
    required this.sliceH,
    this.viewW,
    this.viewH,
  });

  @override
  Widget build(BuildContext context) {
    // Множитель файловых → CSS-пикселей.
    final kx = tileW / fileW;
    final ky = tileH / fileH;
    return ClipRect(
      child: SizedBox(
        width: viewW ?? sliceW,
        height: viewH ?? sliceH,
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: tileW,
          maxHeight: tileH,
          alignment: Alignment(
            tileW <= sliceW ? 0 : (sliceX / (tileW - sliceW)) * 2 - 1,
            tileH <= sliceH ? 0 : (sliceY / (tileH - sliceH)) * 2 - 1,
          ),
          child: Image.asset(
            asset,
            width: tileW,
            height: tileH,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// Карточка ЧУЖОГО отзыва как на NG 2015: шапка (круглый аватар, ник
/// оранжевым, флажок-жалоба, звёзды справа), текст, низ с «React» и
/// счётчиком реакций. Рамки нет — карточки разделены тонкой чертой.
class _ReviewCard extends StatelessWidget {
  final NgReview review;

  /// Текущий пользователь — автор трека: только ему NG даёт отвечать
  /// на отзывы (кнопка Reply в его же карточках).
  final bool canRespond;

  /// Коллбек отправки ответа (текст, id отзыва).
  final Future<String?> Function(String reviewId, String text)? onRespond;

  const _ReviewCard({
    required this.review,
    this.canRespond = false,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Шапка: аватар + ник + флажок … звёзды ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (review.avatarUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipOval(
                    child: Image.network(review.avatarUrl,
                        width: 26, height: 26, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                            width: 26, height: 26)),
                  ),
                ),
              // Левая часть шапки одним Expanded: ник + дата рядом,
              // переполнение сжатиет ник с многоточием. Флажок и звёзды —
              // несжимаемые, всегда прижаты к правому краю без «шатания».
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        review.author,
                        style: ngLink.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Дата сразу после ника, небольшой отступ.
                    if (review.date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(review.date,
                          style: ngLabel.copyWith(fontSize: 9)),
                    ],
                  ],
                ),
              ),
              // Жёлтый флажок «Report Abuse» из карточки.
              if (review.flagUrl.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openFlag(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Image.asset(NgTex.a15('flag'),
                        width: 15, height: 15),
                  ),
                ),
              if (review.hasScore) NgStars(score: review.score),
            ],
          ),
          if (review.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                review.body,
                style: ngBody.copyWith(fontSize: 12, color: ngWhite),
              ),
            ),
          // ── Ответ автора трека (div.authresponse) ─────────────────
          if (review.response != null)
            _AuthorResponse(response: review.response!),
          // ── Reply: только владелец трека ─────────────────────
          if (canRespond && onRespond != null)
            _ReplyButton(
              onTap: () => _showResponseForm(context, review.id),
            ),
        ],
      ),
    );
  }

  /// Форма ответа: «Your Response:» + textarea + Submit, как на NG
  /// (pod с формой `/reviews/responses/create/{id}`).
  void _showResponseForm(BuildContext context, String reviewId) {
    final ctrl = TextEditingController();
    var busy = false;
    showDialog(
      context: context,
      barrierColor: ngBlack.withValues(alpha: 0.72),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> submit() async {
            final text = ctrl.text.trim();
            if (text.isEmpty || busy) return;
            setDlg(() => busy = true);
            final err = await onRespond!(reviewId, text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _showNgSnack(ctx, err ?? 'Response posted!', ok: err == null);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: NgPod(
              icon: 'speech',
              title: 'New Response',
              skin: _skin,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Your Response:', style: ngLabel),
                  const SizedBox(height: 5),
                  // Поле 2024 — тёмно-серое, как на сайте.
                  Container(
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFF282B30),
                      border: Border.all(color: ngHairline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      autofocus: true,
                      cursorColor: ngGold,
                      cursorWidth: 1,
                      onSubmitted: (_) => submit(),
                      style: const TextStyle(color: ngText, fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 5, vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NgButton(
                          label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                      const SizedBox(width: 8),
                      NgButton(
                        label: busy ? 'Sending…' : 'Submit',
                        onPressed: busy ? null : submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Жалоба: NG показывает диалог подтверждения на /flag/add/… —
  /// открываем во внешнем браузере (там нужен залогиненный веб).
  void _openFlag(BuildContext context) {
    final url = review.flagUrl.startsWith('http')
        ? review.flagUrl
        : 'https://www.newgrounds.com${review.flagUrl}';
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Ответ автора трека (div.authresponse): аватар + «ник responds:»
/// и текст — как на NG, под текстом отзыва.
class _AuthorResponse extends StatelessWidget {
  final NgReviewResponse response;
  const _AuthorResponse({required this.response});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(7),
      decoration: const BoxDecoration(
        color: Color(0xFF14110E),
        border: Border.fromBorderSide(BorderSide(color: ngHairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (response.avatarUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ClipOval(
                    child: Image.network(response.avatarUrl,
                        width: 18, height: 18, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 18, height: 18)),
                  ),
                ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: response.author.isEmpty
                          ? 'Author'
                          : response.author,
                      style: ngLink.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    TextSpan(
                      text: ' responds:',
                      style: ngLabel.copyWith(fontSize: 11),
                    ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (response.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                response.body,
                style: ngBody.copyWith(fontSize: 11, color: ngText),
              ),
            ),
        ],
      ),
    );
  }
}

/// Кнопка «Reply» (ngicon-25-comment): иконка-облачко + слово Reply,
/// золотым, справа под текстом отзыва.
class _ReplyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReplyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 14, color: ngGold),
              const SizedBox(width: 4),
              Text('Reply',
                  style: ngLink.copyWith(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// `div.pagenav` 2024: слева «Sort By: Date/Score» (без плашек, ссылки),
/// справа — числовые кнопки-плашки с градиентом `#34393D→#4E575E`
/// (те же, что у кнопок шапки); активная страница — текст без плашки.
class _ReviewPager extends StatelessWidget {
  final int page;
  final int pages;
  final ValueChanged<int> onGo;

  const _ReviewPager({required this.page, required this.pages, required this.onGo});

  @override
  Widget build(BuildContext context) {
    // Номера вокруг текущей: [1 … n-1 n n+1 … last]
    final nums = <int>{
      1,
      pages,
      page - 1,
      page,
      page + 1,
    }.where((n) => n >= 1 && n <= pages).toList()..sort();

    Widget numBtn(int n) {
      final active = n == page;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? null : () => onGo(n),
        child: Container(
          // .pagenav a: та же плашка, что у кнопок шапки 2024; у текущей
          // страницы фон тот же, но цифра белая.
          height: 22,
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
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
            border: Border.all(color: const Color(0xFF34393D), width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: Text(
            '$n',
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: active ? ngWhite : ngGold,
            ),
          ),
        ),
      );
    }

    Widget gap(int a, int b) =>
        b - a > 1 ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Text('…', style: TextStyle(color: ngDim, fontSize: 13)),
            ) : const SizedBox(width: 3);

    var seq = <Widget>[numBtn(nums.first)];
    for (var i = 1; i < nums.length; i++) {
      seq..add(gap(nums[i - 1], nums[i]))..add(numBtn(nums[i]));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Spacer(),
          ...seq,
        ],
      ),
    );
  }
}

/// Форма написания/правки отзыва: textarea 2015 + Submit. Оценка ставится
/// отдельно — лицами в рамке «RATE THIS SUBMISSION!» выше.
/// [existing] — режим правки карандашом: предзаполняет текст,
/// шлёт POST на /reviews/edit/{id}; [onCancel] показывает кнопку отмены.
class _WriteReview extends StatefulWidget {
  final NgViewModel vm;
  final Track track;
  final NgReview? existing;
  final VoidCallback? onCancel;
  final ValueChanged<NgReview> onSaved;

  /// Оценка, связанная с отзывом: берётся из рамки «RATE THIS SUBMISSION!»
  /// (там теперь единственное место выбора оценки). 0 — ещё не выбрана.
  final int stars;

  const _WriteReview({
    required this.vm,
    required this.track,
    required this.onSaved,
    this.existing,
    this.onCancel,
    this.stars = 0,
  });

  @override
  State<_WriteReview> createState() => _WriteReviewState();
}

class _WriteReviewState extends State<_WriteReview> {
  static final _repo = NgRepository();
  late final TextEditingController _ctrl;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.body ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (_busy) return;
    if (widget.vm.currentUser == null) {
      await _requireLogin(context, widget.vm, 'Log in to write a review.');
      return;
    }
    if (text.isEmpty) {
      _showNgSnack(context, 'Review text is empty', ok: false);
      return;
    }
    if (widget.stars < 1) {
      _showNgSnack(context, 'Rate this submission first', ok: false);
      return;
    }
    setState(() => _busy = true);
    final err = _isEdit
        ? await _repo.editReview(
            widget.existing!.id, widget.track.id, text, widget.stars)
        : await _repo.postReview(widget.track.id, text, widget.stars);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _showNgSnack(context, _isEdit ? 'Review updated!' : 'Review posted!');
      // ID у нового отзыва появится при следующей синхронизации с NG —
      // сохраняем то, что знаем; под перерисуется.
      widget.onSaved(NgReview(
        id: _isEdit ? widget.existing!.id : '',
        author: 'You',
        authorSlug: '',
        avatarUrl: '',
        date: _isEdit ? widget.existing!.date : 'Just now',
        score: widget.stars.toDouble(),
        body: text,
      ));
    } else if (err == 'not logged in') {
      await _requireLogin(context, widget.vm, 'Log in to write a review.');
    } else {
      _showNgSnack(context, err, ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isEdit ? 'Edit your review:' : 'Write a review:',
          style: ngLabel.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        // Многострочное поле 2024 — тёмно-серое (rgb(40,43,48)), как
        // поля поиска/ввода на сайте, вместо золотой текстуры 2015.
        Container(
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF282B30),
            border: Border.all(color: ngHairline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: _ctrl,
            maxLines: null,
            cursorColor: ngGold,
            cursorWidth: 1,
            style: const TextStyle(color: ngText, fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Share your feedback on this audio here!',
              hintStyle: TextStyle(color: ngDim, fontSize: 12),
              contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isEdit && widget.onCancel != null) ...[
              NgButton(label: 'Cancel', onPressed: widget.onCancel),
              const SizedBox(width: 8),
            ],
            NgButton(
              label: _busy ? 'Saving…' : 'Submit',
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

/// Блок «Your Review»: моя карточка с пометкой (You), оценкой-рожами
/// и карандашом для правки. Стоит в поде Reviews выше чужих отзывов.
class _MyReviewBlock extends StatelessWidget {
  final NgReview review;
  final VoidCallback onEdit;

  const _MyReviewBlock({required this.review, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Your Review', style: ngLabel.copyWith(color: ngGold)),
            const Spacer(),
            // Карандаш из спрайта a15 — правка текста и оценки.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(NgTex.a15('pencil'),
                    width: 18, height: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14110E),
            border: Border.all(color: ngGold, width: 1),
          ),
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'You',
                      style: ngLink.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 12,
                          color: ngGold),
                    ),
                  ),
                ],
              ),
              if (review.date.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(review.date,
                      style: ngLabel.copyWith(fontSize: 10)),
                ),
              if (review.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    review.body,
                    style: ngBody.copyWith(fontSize: 12, color: ngWhite),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
