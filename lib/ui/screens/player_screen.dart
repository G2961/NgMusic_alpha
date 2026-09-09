import 'package:flutter/material.dart';
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
                      // Плеер в поде с шапкой, как на странице сабмишена 2015
                      _PlayerPod(vm: vm, track: track),
                      if (track != null) ...[
                        // Автор сразу под плеером — до метаданных трека
                        _AuthorPod(track: track),
                        _CreditsPod(track: track),
                        if (track.awards.isNotEmpty) _TrophyPod(track: track),
                        if (track.description != null)
                          _TextPod(
                            icon: 'doc',
                            title: 'Author Comments',
                            text: track.description!,
                          ),
                        _ReviewsPod(track: track),
                      ] else
                        const NgPod(
                          icon: 'audio',
                          title: 'Track Info',
                          skin: _skin,
                          child: NgNotice(
                              text: 'Nothing is playing.', icon: 'audio'),
                        ),
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
  const _PlayerPod({required this.vm, this.track});

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
      child: _PlayerStage(vm: widget.vm, track: track),
    );
  }
}

// ── Блок `.ngp` ──────────────────────────────────────────────────────────────

/// Связывает [NgPlayerStage] с вьюмоделью — сама сцена о ней не знает.
class _PlayerStage extends StatelessWidget {
  final NgViewModel vm;
  final Track? track;
  const _PlayerStage({required this.vm, this.track});

  @override
  Widget build(BuildContext context) {
    final duration = vm.duration ??
        ((track?.duration ?? 0) > 0
            ? Duration(seconds: track!.duration)
            : null);

    return NgPlayerStage(
      artUrls: track?.artworkUrls ?? const [],
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
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
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
          const SizedBox(height: 4),
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
          const NgHr(margin: EdgeInsets.symmetric(vertical: 8)),
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
                EdgeInsets.only(bottom: i == track.awards.length - 1 ? 0 : 10),
            child: _TrophyRow(award: track.awards[i]),
          ),
      ],
    );

    // Один трофей — без зелёной шапки, как в макете.
    if (track.awards.length == 1) {
      return NgPod(
        skin: _skin,
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        child: rows,
      );
    }

    return NgPod(
      icon: 'badge',
      title: 'Trophies',
      skin: _skin,
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
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
        NgTrophyIcon(kind: award.kind, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                award.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: ngWhite,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              if (award.date.isNotEmpty)
                Text(award.date, style: ngLink.copyWith(fontSize: 12)),
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
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: openProfile,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: ngBlack,
                  border: Border.fromBorderSide(BorderSide(color: ngBrown)),
                ),
                child: t.authorIcon == null
                    ? Image.asset(NgTex.defaultAudioIcon, fit: BoxFit.cover)
                    : NgTrackIcon(url: t.authorIcon!, size: 38),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: openProfile,
                  child: Text(
                    artist.isEmpty ? '—' : artist,
                    style: ngLink.copyWith(fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 10),
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
                onPressed: _following ? null : () => _onFollowTap(vm),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 6),
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
  int _pageNum = 1;
  bool _loading = false;
  String? _error;

  /// Мой отзыв (синхронизирован с NG в `_load`); null — ещё не писал.
  NgReview? _myReview;
  /// Сохранённый голос 0..5 (NG убирает votebar после голоса, показываем
  /// сохранённый выбор с подсветкой).
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
    // Свой отзыв и голос тянем параллельно со списком чужих.
    final results = await Future.wait([
      _repo.getReviews(widget.track.id, sort: _sort, page: _pageNum),
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

  void _go(int p) {
    _pageNum = p.clamp(1, _page?.pages ?? 1);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
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
            // Пагинация сверху: «‹ Page N of M ›», как на NG.
            _ReviewPager(page: _page!.page, pages: _page!.pages, onGo: _go),
            const SizedBox(height: 2),
            // Сортировка: Sort By: Date | Score, активный — жирный оранжевый.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sort By: ', style: ngLabel),
                for (var i = 0; i < _sorts.length; i++) ...[
                  if (i > 0) const Text(' | ', style: ngLabel),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _sort == _sorts[i].$1
                        ? null
                        : () {
                            _sort = _sorts[i].$1;
                            _pageNum = 1;
                            _load();
                          },
                    child: Text(
                      _sorts[i].$2,
                      style: _sort == _sorts[i].$1
                          ? ngLabel.copyWith(
                              color: ngGold,
                              fontWeight: FontWeight.bold)
                          : ngLabel,
                    ),
                  ),
                ],
              ],
            ),
            const NgHr(margin: EdgeInsets.symmetric(vertical: 6)),
            // Карточки разделены тонкой чертой, без рамок.
            for (var i = 0; i < _page!.items.length; i++) ...[
              _ReviewCard(review: _page!.items[i]),
              if (i < _page!.items.length - 1)
                const NgHr(margin: EdgeInsets.symmetric(vertical: 4)),
            ],
            const SizedBox(height: 6),
            _ReviewPager(page: _page!.page, pages: _page!.pages, onGo: _go),
          ],
        ],
      ),
    );
  }
}

/// Votebar 2015 «RATE THIS SUBMISSION!»: шесть лиц (0..5) из спрайта
/// `vp/vote-darn.png` (зелёный скин аудио-портала). Тап ставит голос
/// сразу: лицо N → vote N×2 (NG ждёт 0..10).
///
/// NG после голоса убирает votebar со страницы — сохранённый голос приходит
/// извне ([savedVote]) и подсвечивается: выбранное лицо ярко (ряд нажатых),
/// остальные слегка притенены.
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

  int _voted = 0; // локальное состояние (0 — нет)
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _voted = widget.savedVote ?? 0;
  }

  @override
  void didUpdateWidget(_VoteBar old) {
    super.didUpdateWidget(old);
    if (widget.savedVote != old.savedVote) {
      _voted = widget.savedVote ?? 0;
    }
  }

  Future<void> _vote(int face, NgViewModel vm) async {
    if (_busy || face < 0 || face > 5) return;
    if (vm.currentUser == null) {
      await _requireLogin(context, vm, 'Log in to rate this audio.');
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    final res = await _repo.voteTrack(widget.trackId, face);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res == null) {
        _note = 'Vote failed — try again';
      } else {
        _voted = face;
        _note = res.waiting ? 'Waiting for more votes…' : 'You voted $face!';
        widget.onVoted(face);
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
                    (_voted > 0 ? 'You rated this $_voted/5' : 'RATE THIS SUBMISSION!'),
            style: TextStyle(
              fontFamily: ngHeaderFont,
              fontSize: 16,
              color: (_note != null || _voted > 0) && !_busy ? ngGold : ngWhite,
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
          _VoteFaceRow(
            selected: _voted,
            dimUnselected: _voted > 0,
            enabled: !_busy,
            onSelect: (f) => _vote(f, vm),
          ),
        ],
      ),
    );
  }
}

/// Ряд из шести лиц (0..5). [selected] — выбранное лицо (0 — ничего).
/// [dimUnselected] — слегка притенить невыбранные (после голоса).
/// Переиспользуется в вотбаре и в форме отзыва.
class _VoteFaceRow extends StatelessWidget {
  final int selected;
  final bool enabled;
  final bool dimUnselected;
  final ValueChanged<int> onSelect;

  const _VoteFaceRow({
    required this.selected,
    required this.onSelect,
    this.enabled = true,
    this.dimUnselected = false,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var f = 0; f <= 5; f++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onSelect(f) : null,
              child: Opacity(
                // Выбранное — ярко (ряд нажатых лиц), остальные — полутень.
                opacity: dimUnselected && selected != f ? 0.45 : 1,
                child: _VoteFace(
                    face: f, active: selected == f && selected > 0),
              ),
            ),
        ],
      ),
    );
  }
}

/// Одно лицо votebar: вырезка 50×55 из спрайта 300×230.
/// Столбец f (0..5) → alignX; idle-ряд на y=55, нажатый — внизу (y=175).
class _VoteFace extends StatelessWidget {
  final int face;
  final bool active;
  const _VoteFace({required this.face, required this.active});

  @override
  Widget build(BuildContext context) {
    // alignX: 6 столбцов по 50px в 300px. alignY: idle-ряд (y=55) → -0.371,
    // нажатый ряд (низ) → 1.0.
    final align = Alignment(-1 + face * 0.4, active ? 1.0 : -0.371);
    return SizedBox(
      width: 50,
      height: 55,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: 300,
          maxHeight: 230,
          alignment: align,
          child: Image.asset(
            'assets/ng2015/vp/vote-darn.png',
            width: 300,
            height: 230,
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
  const _ReviewCard({required this.review});

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
              Expanded(
                child: Text(
                  review.author,
                  style: ngLink.copyWith(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              if (review.hasScore)
                NgStars(score: review.score),
            ],
          ),
          if (review.date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(review.date,
                  style: ngLabel.copyWith(fontSize: 9)),
            ),
          if (review.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                review.body,
                style: ngBody.copyWith(fontSize: 12, color: ngWhite),
              ),
            ),
          // ── Низ: React слева, число реакций справа ────────────────
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                // Кружок-смайлик: mood-6 из спрайта emotes — рисуем кружок.
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ngGold, width: 1),
                  ),
                ),
                const SizedBox(width: 4),
                Text('React',
                    style: ngLabel.copyWith(
                        color: ngGold, fontSize: 10)),
                const Spacer(),
                if (review.reactions != null && review.reactions! > 0)
                  Text('${review.reactions}',
                      style: ngLabel.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
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

/// Пагинация «« ‹ Page N of M › »» — как на NG, всегда по центру.
class _ReviewPager extends StatelessWidget {
  final int page;
  final int pages;
  final ValueChanged<int> onGo;

  const _ReviewPager({required this.page, required this.pages, required this.onGo});

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, int? target) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: target == null || target < 1 || target > pages
              ? null
              : () => onGo(target),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontFamily: ngHeaderFont,
                color: target == null ? ngDim : ngGold,
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          btn('«', 1),
          btn('‹', page > 1 ? page - 1 : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Page $page of $pages', style: ngLabel),
          ),
          btn('›', page < pages ? page + 1 : null),
          btn('»', pages),
        ],
      ),
    );
  }
}

/// Форма написания/правки отзыва: textarea 2015 + рожи оценки + Submit.
/// [existing] — режим правки карандашом: предзаполняет текст и оценку,
/// шлёт POST на /reviews/edit/{id}; [onCancel] показывает кнопку отмены.
class _WriteReview extends StatefulWidget {
  final NgViewModel vm;
  final Track track;
  final NgReview? existing;
  final VoidCallback? onCancel;
  final ValueChanged<NgReview> onSaved;

  const _WriteReview({
    required this.vm,
    required this.track,
    required this.onSaved,
    this.existing,
    this.onCancel,
  });

  @override
  State<_WriteReview> createState() => _WriteReviewState();
}

class _WriteReviewState extends State<_WriteReview> {
  static final _repo = NgRepository();
  late final TextEditingController _ctrl;
  late int _stars;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.body ?? '');
    _stars = widget.existing?.score.round().clamp(0, 5) ?? 0;
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
    if (_stars < 1) {
      _showNgSnack(context, 'Pick a score first', ok: false);
      return;
    }
    setState(() => _busy = true);
    final err = _isEdit
        ? await _repo.editReview(
            widget.existing!.id, widget.track.id, text, _stars)
        : await _repo.postReview(widget.track.id, text, _stars);
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
        score: _stars.toDouble(),
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
        // Многострочное поле в стиле input 2015 — та же золотистая плашка.
        Container(
          height: 72,
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
          child: TextField(
            controller: _ctrl,
            maxLines: null,
            cursorColor: ngInk,
            cursorWidth: 1,
            style: const TextStyle(color: Color(0xFF1B1006), fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Share your feedback on this audio here!',
              hintStyle:
                  TextStyle(color: Color(0xFF7A5A20), fontSize: 12),
              contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Your score:', style: ngLabel),
        const SizedBox(height: 4),
        _VoteFaceRow(
          selected: _stars,
          dimUnselected: _stars > 0,
          onSelect: (f) => setState(() => _stars = f),
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
                  if (review.hasScore)
                    _VoteFaceRow(
                      selected: review.score.round().clamp(0, 5),
                      dimUnselected: true,
                      enabled: false,
                      onSelect: (_) {},
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
