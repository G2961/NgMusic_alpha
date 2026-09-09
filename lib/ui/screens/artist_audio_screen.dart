import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/track.dart';
import '../../data/repository/ng_repository.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/ng_retro.dart';
import 'artist_track_row.dart';

/// Аудио-портал 2015 носил зелёный скин (`body.green`).
const _skin = NgSkin.gold;

/// Полный список аудио автора: то же, что `<username>.newgrounds.com/audio`
/// с догрузкой по скроллу. На самой странице автора список обрезан до восьми
/// строк (как в 2015), а сюда ведёт плашка «View All »».
class ArtistAudioScreen extends StatefulWidget {
  final String artist;

  /// Уже загруженная первая страница — чтобы не ждать повторный запрос.
  final List<Track> initialTracks;

  /// С какой страницы продолжать догрузку (первая уже в [initialTracks]).
  final int nextPage;

  const ArtistAudioScreen({
    super.key,
    required this.artist,
    this.initialTracks = const [],
    this.nextPage = 2,
  });

  @override
  State<ArtistAudioScreen> createState() => _ArtistAudioScreenState();
}

class _ArtistAudioScreenState extends State<ArtistAudioScreen> {
  final _repo = NgRepository();
  final _scroll = ScrollController();

  late List<Track> _tracks = [...widget.initialTracks];
  late int _nextPage = widget.nextPage;
  late bool _loading = _tracks.isEmpty;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (_tracks.isEmpty) _loadFirstPage();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (tracks, _) =
          await _repo.getArtistTracksPage(widget.artist, page: 1);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _nextPage = 2;
        _hasMore = tracks.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  /// Страница NG отдаёт ~30 записей за запрос — отдельная «порция» не нужна,
  /// достаточно идти по страницам, пока приходят новые id.
  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final (more, _) =
          await _repo.getArtistTracksPage(widget.artist, page: _nextPage);
      final ids = _tracks.map((t) => t.id).toSet();
      final fresh = more.where((t) => !ids.contains(t.id)).toList();
      if (!mounted) return;
      setState(() {
        _tracks = [..._tracks, ...fresh];
        _hasMore = fresh.isNotEmpty;
        _nextPage++;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();

    final Widget body;
    if (_loading) {
      body = const SingleChildScrollView(child: NgLoading());
    } else if (_error != null && _tracks.isEmpty) {
      body = SingleChildScrollView(
        child: NgNotice(
          text: 'Could not load tracks.\n$_error',
          icon: 'flag',
          action: NgButton(
            label: 'Retry',
            icon: 'refresh',
            onPressed: _loadFirstPage,
          ),
        ),
      );
    } else if (_tracks.isEmpty) {
      body = const SingleChildScrollView(
        child: NgNotice(text: 'No tracks yet.', icon: 'audio'),
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.only(bottom: vm.currentTrack != null ? 90 : 12),
        itemCount: _tracks.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _tracks.length) return const NgLoading(width: 100);
          return ArtistTrackRow(
            index: i,
            track: _tracks[i],
            allTracks: _tracks,
            skin: _skin,
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.artist,
                          style: ngLink.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _tracks.isEmpty
                              ? 'All audio'
                              : 'All audio · ${_tracks.length}'
                                  '${_hasMore ? '+' : ''} tracks',
                          style: ngLabel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            Expanded(
              child: NgPageColumn(
                child: NgPod.fill(
                  icon: 'audio',
                  title: 'Audio',
                  skin: _skin,
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
