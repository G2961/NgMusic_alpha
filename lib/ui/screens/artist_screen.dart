import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/ng_user.dart';
import '../../data/model/track.dart';
import '../../data/repository/ng_repository.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/ng_retro.dart';
import 'artist_audio_screen.dart';
import 'artist_track_row.dart';
import 'login_screen.dart';

/// Аудио-портал 2015 носил зелёный скин (`body.green`).
const _skin = NgSkin.gold;

/// Сколько строк аудио показывать на самой странице автора.
/// В 2015 профиль показывал короткую выжимку, а не весь портфолио.
const _kAudioPreview = 8;

/// Страница автора в вёрстке Newgrounds 2015: под с аватаром и статистикой,
/// под со списком треков. Без Material-карточек и скруглений.
class ArtistScreen extends StatefulWidget {
  final String artist;
  const ArtistScreen({super.key, required this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  final _repo = NgRepository();

  NgUser? _profile;
  List<Track> _tracks = [];
  bool _loadingProfile = true;
  bool _loadingTracks = true;
  String? _error;

  /// На NG есть ещё страницы аудио — значит, полный список имеет смысл.
  bool _hasMore = false;

  /// Состояние подписки: null — ещё не известно (кнопка ждёт, а не врёт).
  bool? _isFollowing;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTracks();
  }

  Future<void> _loadProfile() async {
    // Профиль и статус подписки читаются одним запросом: getUserProfile
    // сам шлёт сессионные куки и разбирает кнопку favefollow. Отдельный
    // getFollowStatus нужен только после входа из этого же экрана.
    try {
      final profile = await _repo.getUserProfile(widget.artist);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadingProfile = false;
        // null — статус неизвестен (гость либо разметка не совпала),
        // и кнопка не переключается в «Following» сама собой.
        _isFollowing = profile?.isFollowing;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadTracks() async {
    try {
      final (tracks, nextUrl) =
          await _repo.getArtistTracksPage(widget.artist, page: 1);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        // Первая страница отдаёт ~30 записей; «есть ещё» — либо ссылка
        // load_more, либо просто больше строк, чем влезает в выжимку.
        _hasMore = nextUrl != null || tracks.length > _kAudioPreview;
        _loadingTracks = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loadingTracks = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final isSelf =
        vm.currentUser?.username.toLowerCase() == widget.artist.toLowerCase();

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(artist: widget.artist),
            Expanded(
              child: NgPageColumn(
                child: ListView(
                  padding: EdgeInsets.only(
                      bottom: vm.currentTrack != null ? 90 : 12),
                  children: [
                    _profilePod(isSelf: isSelf),
                    _tracksPod(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Под профиля ─────────────────────────────────────────────────────────────

  Widget _profilePod({required bool isSelf}) {
    final p = _profile;

    final items = <NgInfoItem>[
      if (p?.fans != null) NgInfoItem('Fans', p!.fans!),
      if (p?.audioCount != null) NgInfoItem('Audio', p!.audioCount!),
      if (p?.level != null) NgInfoItem('Level', p!.level!),
      if (p?.joinDate != null) NgInfoItem('Joined', p!.joinDate!),
      if (p?.country != null) NgInfoItem('Country', p!.country!),
      if (p?.age != null) NgInfoItem('Age', p!.age!),
      if (p?.gender != null) NgInfoItem('Gender', p!.gender!),
    ];

    return NgPod(
      icon: 'user',
      title: widget.artist,
      skin: _skin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Аватар в рамке ngBrown — как `.item-icon` в разметке 2015.
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: ngBlack,
                  border: Border.fromBorderSide(
                      BorderSide(color: ngBrown, width: 2)),
                ),
                child: _loadingProfile
                    ? const SizedBox.shrink()
                    : p?.avatarUrl == null
                        ? Image.asset(NgTex.defaultAudioIcon, fit: BoxFit.cover)
                        : NgTrackIcon(url: p!.avatarUrl!, size: 66),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ник золотым, как ссылки NG.
                    Text(
                      widget.artist,
                      style: ngLink.copyWith(fontSize: 17),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.artist.toLowerCase()}.newgrounds.com',
                      style: ngLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (!isSelf) _followButton(),
                  ],
                ),
              ),
            ],
          ),
          if (_loadingProfile) const NgLoading(width: 100),
          if (items.isNotEmpty) ...[
            const NgHr(margin: EdgeInsets.symmetric(vertical: 9)),
            NgInfoTable(items: items, skin: _skin, labelWidth: 66),
          ],
        ],
      ),
    );
  }

  Widget _followButton() {
    final following = _isFollowing == true;
    return Align(
      alignment: Alignment.centerLeft,
      child: NgButton(
        label: _followBusy ? '…' : (following ? 'Following' : 'Follow'),
        icon: following ? 'check' : 'user-add',
        onPressed: _followBusy ? null : _onFollowTap,
      ),
    );
  }

  Future<void> _onFollowTap() async {
    final vm = context.read<NgViewModel>();
    if (vm.currentUser == null) {
      final doLogin = await showDialog<bool>(
        context: context,
        barrierColor: ngBlack.withValues(alpha: 0.72),
        builder: (_) => const NgLoginPromptDialog(
          message: 'Log in to follow artists.',
          skin: _skin,
        ),
      );
      if (doLogin == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (mounted) {
          await context.read<NgViewModel>().fetchUser();
          final status = await _repo.getFollowStatus(widget.artist);
          if (mounted) setState(() => _isFollowing = status);
        }
      }
      return;
    }

    final target = !(_isFollowing ?? false);
    setState(() => _followBusy = true);
    final confirmed = await vm.setFollow(widget.artist.toLowerCase(), target);
    if (!mounted) return;
    final ok = confirmed == target;
    setState(() {
      _followBusy = false;
      if (ok) _isFollowing = target;
    });
    _snack(
      ok
          ? (target
              ? 'Now following ${widget.artist}!'
              : 'Unfollowed ${widget.artist}')
          : (target ? 'Failed to follow' : 'Failed to unfollow'),
      ok: ok,
    );
  }

  // ── Под треков ──────────────────────────────────────────────────────────────

  Widget _tracksPod() {
    final preview = _tracks.length > _kAudioPreview
        ? _tracks.sublist(0, _kAudioPreview)
        : _tracks;
    final hidden = _tracks.length - preview.length;

    final Widget body;
    if (_loadingTracks) {
      body = const NgLoading();
    } else if (_error != null && _tracks.isEmpty) {
      body = NgNotice(
        text: 'Could not load tracks.\n$_error',
        icon: 'flag',
        action: NgButton(
          label: 'Retry',
          icon: 'refresh',
          onPressed: () {
            setState(() {
              _loadingTracks = true;
              _error = null;
            });
            _loadTracks();
          },
        ),
      );
    } else if (_tracks.isEmpty) {
      body = const NgNotice(text: 'No tracks yet.', icon: 'audio');
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < preview.length; i++)
            ArtistTrackRow(
              index: i,
              track: preview[i],
              allTracks: preview,
              skin: _skin,
            ),
          // Строка-«ещё» в духе `.pagenav`: остаток списка живёт на своём
          // экране с догрузкой по скроллу.
          if (_hasMore)
            NgListRow(
              index: preview.length,
              skin: _skin,
              onTap: _openAllAudio,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hidden > 0
                          ? 'View all audio ($hidden+ more) »'
                          : 'View all audio »',
                      style: ngLink,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return NgPod.list(
      icon: 'audio',
      title: 'Audio',
      skin: _skin,
      // Плашка в углу шапки только когда ей есть куда вести: раньше здесь
      // висел неклик*абельный ярлык с числом треков и выглядел как кнопка.
      action: _hasMore
          ? NgPlateLink(label: 'View All »', onTap: _openAllAudio)
          : null,
      child: body,
    );
  }

  void _openAllAudio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistAudioScreen(
          artist: widget.artist,
          initialTracks: _tracks,
        ),
      ),
    );
  }

  void _snack(String text, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(color: ngWhite, fontSize: 12)),
      backgroundColor: ok ? ngOrange : ngRed,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─── Шапка ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String artist;
  const _TopBar({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: ngBlack,
        border: Border(bottom: BorderSide(color: ngHairline)),
      ),
      child: Row(
        children: [
          NgIconButton(
            icon: 'arrow-left',
            padding: 10,
            tooltip: 'Back',
            onTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              artist,
              style: ngH2.copyWith(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
