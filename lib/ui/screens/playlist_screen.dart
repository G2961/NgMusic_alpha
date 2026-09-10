import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/playlist.dart';
import '../../data/repository/local_db.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/ng_retro.dart';
import 'artist_screen.dart';
import 'player_screen.dart';

/// Аудио-портал 2015 носил зелёный скин (`body.green`).
const _skin = NgSkin.gold;

/// Содержимое плейлиста в вёрстке 2015: один под на весь экран, внутри —
/// строки `table.audiolist tr` с чередованием фона.
class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<PlaylistTrack> _tracks = [];
  bool _loading = true;

  /// Для зеркала NG: кэш пуст, но сверка с сайтом ещё идёт — показываем
  /// загрузку, а не «No tracks»: честный ответ «пусто» только после сверки.
  bool _checking = false;
  late Playlist _playlist = widget.playlist;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Кэш отдаётся сразу, для зеркала NG тихо сверяется с сайтом в фоне —
    // свежий список приедет в onSynced (новые добавятся, удалённые уйдут).
    final lvm = context.read<LibraryViewModel>();
    final isNg = _playlist.ngId != null;
    final cached = await lvm.loadPlaylistTracks(_playlist, onSynced: (fresh) {
      if (!mounted) return;
      setState(() {
        _tracks = fresh;
        _checking = false;
      });
    });
    if (!mounted) return;
    setState(() {
      _tracks = cached;
      _loading = false;
      // Кэш пуст, а сверка с NG в полёте — крутим загрузку до её ответа.
      _checking = isNg && cached.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final lvm = context.watch<LibraryViewModel>();
    final isNg = _playlist.ngId != null;

    final Widget body;
    if (_loading || (_checking && _tracks.isEmpty)) {
      // Первое открытие: кэш пуст и/или идёт сверка с NG — честно показываем
      // загрузку. «No tracks» — только после ответа сайта, если и там пусто.
      body = const SingleChildScrollView(child: NgLoading());
    } else if (_tracks.isEmpty) {
      body = const SingleChildScrollView(
        child: NgNotice(
          text: 'No tracks yet.\nAdd tracks from the audio portal.',
          icon: 'list',
        ),
      );
    } else {
      body = ListView.builder(
        padding: EdgeInsets.only(bottom: vm.currentTrack != null ? 90 : 12),
        itemCount: _tracks.length,
        itemBuilder: (ctx, i) => _PlaylistTrackRow(
          index: i,
          pt: _tracks[i],
          allTracks: _tracks,
          onRemove: () => _removeTrack(_tracks[i]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              title: _playlist.name,
              subtitle: isNg ? 'Newgrounds playlist' : 'Local playlist',
              busy: lvm.isSyncingNg,
              onEdit: _showRename,
              onDelete: _confirmDelete,
            ),
            Expanded(
              child: NgPageColumn(
                child: NgPod.fill(
                  icon: 'list',
                  title: _playlist.name,
                  skin: _skin,
                  action: _tracks.isEmpty
                      ? null
                      : NgPlateLink(
                          label: 'Play All »',
                          onTap: () => _playAll(vm),
                        ),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playAll(NgViewModel vm) {
    if (_tracks.isEmpty) return;
    final tracks = _tracks.map(LocalDb.playlistTrackToTrack).toList();
    vm.setQueueContext(tracks);
    vm.playTrack(tracks.first);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  Future<void> _removeTrack(PlaylistTrack pt) async {
    final lvm = context.read<LibraryViewModel>();
    // Оптимистично убираем из списка сразу — не ждём сеть.
    setState(() => _tracks.removeWhere((t) => t.trackId == pt.trackId));
    final ok = await lvm.removeTrackFromPlaylist(_playlist.id!, pt.trackId);
    if (!mounted) return;
    if (!ok) {
      _snack(lvm.lastError ?? 'Failed to remove track', ok: false);
      lvm.clearError();
      await _load(); // вернуть как было
    }
  }

  Future<void> _showRename() async {
    final name = await showDialog<String>(
      context: context,
      barrierColor: ngBlack.withValues(alpha: 0.72),
      builder: (_) => _RenameDialog(initial: _playlist.name),
    );
    if (name == null || !mounted) return;

    final lvm = context.read<LibraryViewModel>();
    final ok = await lvm.renamePlaylist(_playlist.id!, name);
    if (!mounted) return;
    if (!ok) {
      _snack(lvm.lastError ?? 'Failed to rename', ok: false);
      lvm.clearError();
      return;
    }
    setState(() => _playlist = _playlist.copyWith(name: name));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: ngBlack.withValues(alpha: 0.72),
      builder: (_) => _ConfirmDeleteDialog(
        name: _playlist.name,
        onNewgrounds: _playlist.ngId != null,
      ),
    );
    if (confirmed != true || !mounted) return;

    final lvm = context.read<LibraryViewModel>();
    final ok = await lvm.deletePlaylist(_playlist.id!);
    if (!mounted) return;
    if (!ok) {
      _snack(lvm.lastError ?? 'Failed to delete', ok: false);
      lvm.clearError();
      return;
    }
    Navigator.pop(context);
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

/// Чёрная полоса `.sitelinks`: «назад», название, кнопки правки и удаления.
class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ngLink.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(subtitle, style: ngLabel),
              ],
            ),
          ),
          if (busy)
            const NgLoading(compact: true, size: 22),
          NgIconButton(
            icon: 'pencil',
            padding: 10,
            tooltip: 'Rename',
            onTap: busy ? null : onEdit,
          ),
          NgIconButton(
            icon: 'trash',
            padding: 10,
            tooltip: 'Delete playlist',
            onTap: busy ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Строка трека ─────────────────────────────────────────────────────────────

class _PlaylistTrackRow extends StatelessWidget {
  final int index;
  final PlaylistTrack pt;
  final List<PlaylistTrack> allTracks;
  final VoidCallback onRemove;

  const _PlaylistTrackRow({
    required this.index,
    required this.pt,
    required this.allTracks,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final isActive = vm.currentTrack?.id == pt.trackId;

    return NgAudioRow(
      index: index,
      skin: _skin,
      iconUrl: pt.iconUrl,
      title: pt.title,
      genre: pt.genre ?? '',
      artist: pt.artist,
      playing: isActive,
      paused: isActive && !vm.isPlaying,
      onTap: () {
        final tracks = allTracks.map(LocalDb.playlistTrackToTrack).toList();
        vm.setQueueContext(tracks);
        vm.playTrack(tracks[index]);
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
      },
      onArtistTap: pt.artist.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ArtistScreen(artist: pt.artist)),
              ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pt.duration > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(_fmt(pt.duration), style: ngLabel),
            ),
          NgIconButton(
            icon: 'close',
            padding: 5,
            tooltip: 'Remove from playlist',
            onTap: onRemove,
          ),
        ],
      ),
    );
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─── Диалоги ──────────────────────────────────────────────────────────────────

/// Переименование: под с полем ввода, возвращает новое имя или null.
class _RenameDialog extends StatefulWidget {
  final String initial;
  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    // NG требует минимум 3 символа (minlength в форме /playlists/edit).
    if (name.isEmpty || name == widget.initial) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: NgPod(
        icon: 'quill',
        title: 'Rename Playlist',
        skin: _skin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Playlist name', style: ngLabel),
            const SizedBox(height: 5),
            NgTextField(
              controller: _ctrl,
              focusNode: _focus,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NgButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                NgButton(label: 'Save', icon: 'save', onPressed: _submit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Подтверждение удаления. Для зеркала NG предупреждает, что уйдёт и с сайта.
class _ConfirmDeleteDialog extends StatelessWidget {
  final String name;
  final bool onNewgrounds;

  const _ConfirmDeleteDialog({
    required this.name,
    required this.onNewgrounds,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: NgPod(
        icon: 'flag',
        title: 'Delete Playlist?',
        skin: NgSkin.red,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('«$name» will be permanently deleted.', style: ngBody),
            if (onNewgrounds) ...[
              const SizedBox(height: 8),
              const Text(
                'This playlist lives on your Newgrounds account — '
                'it will be deleted there too.',
                style: ngBodySmall,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NgButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context, false),
                ),
                const SizedBox(width: 8),
                NgButton(
                  label: 'Delete',
                  icon: 'trash',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
