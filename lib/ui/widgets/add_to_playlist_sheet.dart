import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/playlist.dart';
import '../../data/model/track.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../theme/ng_theme.dart';
import 'ng_chrome.dart';
import 'ng_playlist_dialogs.dart';
import 'ng_retro.dart';

/// Аудио-портал 2015 носил зелёный скин (`body.green`).
const _skin = NgSkin.gold;

/// Всплывашка «добавить в плейлист» в вёрстке 2015.
///
/// Две вкладки-плашки (`.navbar`) — плейлисты приложения и зеркала аккаунта
/// NG, поиск по названию (листать 80+ плейлистов пальцем невозможно) и
/// кнопка «+ Playlist »» в шапке пода, которая переиспользует общий диалог
/// создания с выбором места.
Future<void> showAddToPlaylistSheet(BuildContext context, Track track) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: ngBlack.withValues(alpha: 0.72),
    // Без скруглений и без «ручки» — в 2015 таких элементов не было.
    shape: const RoundedRectangleBorder(),
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<LibraryViewModel>(),
      child: _AddToPlaylistSheet(track: track),
    ),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  final Track track;
  const _AddToPlaylistSheet({required this.track});

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final _search = TextEditingController();
  int _tab = 0;
  String _query = '';

  /// id плейлиста, в который сейчас идёт запись (блокирует повторные тапы).
  int? _busyId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lvm = context.watch<LibraryViewModel>();
    final local = _filter(lvm.localPlaylists);
    final ng = _filter(lvm.ngPlaylists);
    final list = _tab == 0 ? local : ng;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        // Половина экрана: список должен листаться, но трек под шторкой видно.
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            NgNavPlates(
              labels: ['This app (${local.length})', 'Newgrounds (${ng.length})'],
              index: _tab,
              onSelect: (i) => setState(() => _tab = i),
              accents: const [NgAccent.blue, NgAccent.orange],
            ),
            Expanded(
              child: NgPageColumn(
                child: NgPod.fill(
                  icon: 'list',
                  title: 'Add to Playlist',
                  skin: _skin,
                  action: NgPlateLink(
                    label: '+ Playlist »',
                    onTap: () => _create(lvm),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                        child: NgTextField(
                          controller: _search,
                          hint: 'Filter playlists',
                          onChanged: (v) => setState(() => _query = v),
                          suffix: _query.isEmpty
                              ? null
                              : NgIconButton(
                                  icon: 'close',
                                  padding: 4,
                                  onTap: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                      ),
                      Expanded(child: _list(lvm, list)),
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

  List<Playlist> _filter(List<Playlist> src) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return src;
    return src.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  Widget _list(LibraryViewModel lvm, List<Playlist> list) {
    if (lvm.isLoading && lvm.playlists.isEmpty) {
      return const SingleChildScrollView(child: NgLoading());
    }
    if (_tab == 1 && !lvm.isLoggedIn) {
      return const SingleChildScrollView(
        child: NgNotice(
          text: 'Log in to use playlists\non your Newgrounds account.',
          icon: 'user',
        ),
      );
    }
    if (list.isEmpty) {
      return SingleChildScrollView(
        child: NgNotice(
          text: _query.isNotEmpty
              ? 'Nothing matches "$_query".'
              : (_tab == 0
                  ? 'No playlists in the app yet.'
                  : 'No playlists on your NG account yet.'),
          icon: _query.isNotEmpty ? 'search' : 'folder',
          action: _query.isNotEmpty
              ? null
              : NgButton(
                  label: 'New Playlist',
                  icon: 'add',
                  onPressed: () => _create(lvm),
                ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: list.length,
      itemBuilder: (_, i) => _PlaylistPickRow(
        index: i,
        playlist: list[i],
        busy: _busyId == list[i].id,
        locked: _busyId != null && _busyId != list[i].id,
        onTap: () => _add(lvm, list[i]),
      ),
    );
  }

  Future<void> _add(LibraryViewModel lvm, Playlist pl) async {
    if (_busyId != null) return;
    setState(() => _busyId = pl.id);
    final ok = await lvm.addTrackToPlaylist(pl, widget.track);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (ok) {
      Navigator.pop(context);
      _snack(context, 'Added to "${pl.name}"');
      return;
    }
    final error = lvm.lastError;
    lvm.clearError();
    _snack(context, error ?? 'Could not add the track', ok: false);
  }

  /// Создание нового плейлиста прямо с треком: NG всё равно требует запись
  /// при создании, так что «создать и добавить» — один запрос.
  Future<void> _create(LibraryViewModel lvm) async {
    final result = await showNgCreatePlaylistDialog(
      context,
      canUseNg: lvm.isLoggedIn,
      target: _tab == 1 ? PlaylistTarget.newgrounds : PlaylistTarget.local,
      skin: _skin,
    );
    if (result == null || !mounted) return;

    setState(() => _busyId = -1);
    final pl = await lvm.createPlaylistWithTrack(
      result.name,
      target: result.target,
      track: widget.track,
    );
    if (!mounted) return;
    setState(() => _busyId = null);
    if (pl != null) {
      Navigator.pop(context);
      _snack(context, 'Created "${result.name}" and added the track');
      return;
    }
    final error = lvm.lastError;
    lvm.clearError();
    _snack(context, error ?? 'Could not create the playlist', ok: false);
  }

  void _snack(BuildContext context, String text, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(color: ngWhite, fontSize: 12)),
      backgroundColor: ok ? ngOrange : ngRed,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      duration: const Duration(seconds: 2),
    ));
  }
}

/// Строка выбора плейлиста: иконка папки (локальный) или Пико (зеркало NG).
class _PlaylistPickRow extends StatelessWidget {
  final int index;
  final Playlist playlist;
  final bool busy;
  final bool locked;
  final VoidCallback onTap;

  const _PlaylistPickRow({
    required this.index,
    required this.playlist,
    required this.busy,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: NgListRow(
        index: index,
        skin: _skin,
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Row(
            children: [
              Image.asset(
                NgTex.h2(playlist.ngId != null ? 'pico' : 'folder'),
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  playlist.name,
                  style: ngLink,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (busy)
                const SizedBox(
                  width: 40,
                  child: NgStripedBar(value: 1, height: 8),
                )
              else
                Image.asset(NgTex.a15('add'), width: 15, height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
