import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/track.dart';
import '../../services/track_downloader.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/ng_retro.dart';
import 'login_screen.dart';
import 'player_screen.dart';

/// Строка трека на странице автора: `table.audiolist tr` с иконками действий.
///
/// Общая для короткого списка на самой странице и для полного списка в
/// [ArtistAudioScreen], поэтому вынесена из `artist_screen.dart`.
class ArtistTrackRow extends StatefulWidget {
  final int index;
  final Track track;
  final List<Track> allTracks;
  final NgSkin skin;

  const ArtistTrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.allTracks,
    this.skin = NgSkin.gold,
  });

  @override
  State<ArtistTrackRow> createState() => _ArtistTrackRowState();
}

class _ArtistTrackRowState extends State<ArtistTrackRow> {
  bool _downloading = false;

  Future<void> _onFavTap(NgViewModel vm, LibraryViewModel lvm) async {
    if (vm.currentUser == null) {
      final doLogin = await showDialog<bool>(
        context: context,
        barrierColor: ngBlack.withValues(alpha: 0.72),
        builder: (_) => NgLoginPromptDialog(
          message: 'Log in to save favorites.',
          skin: widget.skin,
        ),
      );
      if (doLogin == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (mounted) await context.read<NgViewModel>().fetchUser();
      }
      return;
    }
    final ok = await lvm.toggleFavorite(widget.track);
    if (!mounted || ok) return;
    final error = lvm.lastError;
    lvm.clearError();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Failed to save favorite',
          style: const TextStyle(color: ngWhite, fontSize: 12)),
      backgroundColor: ngRed,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final lvm = context.watch<LibraryViewModel>();
    final t = widget.track;
    final isActive = vm.currentTrack?.id == t.id;
    final isFav = lvm.isFavorite(t.id);
    final syncing = lvm.isFavoriteSyncing(t.id);

    return NgAudioRow(
      index: widget.index,
      skin: widget.skin,
      iconUrl: t.aIconUrl,
      title: t.title,
      genre: t.genre,
      // Автора не дублируем — это его собственная страница.
      artist: '',
      playing: isActive,
      paused: isActive && !vm.isPlaying,
      onTap: () {
        vm.setQueueContext(widget.allTracks);
        vm.playTrack(t);
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.duration > 0)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(_fmt(t.duration), style: ngLabel),
            ),
          NgIconButton(
            icon: isFav ? 'fav-on' : 'fav-add',
            padding: 5,
            tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
            onTap: syncing ? null : () => _onFavTap(vm, lvm),
          ),
          NgIconButton(
            icon: 'playlist',
            padding: 5,
            tooltip: 'Add to playlist',
            onTap: () => showAddToPlaylistSheet(context, t),
          ),
          NgIconButton(
            icon: 'download',
            padding: 5,
            tooltip: 'Download',
            onTap: _downloading
                ? null
                : () async {
                    setState(() => _downloading = true);
                    await TrackDownloader.download(t, context);
                    if (mounted) setState(() => _downloading = false);
                  },
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

/// Диалог «нужен вход» в виде пода 2015.
class NgLoginPromptDialog extends StatelessWidget {
  final String message;
  final NgSkin skin;

  const NgLoginPromptDialog({
    super.key,
    required this.message,
    this.skin = NgSkin.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: NgPod(
        icon: 'user',
        title: 'Login Required',
        skin: skin,
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
                  onPressed: () => Navigator.pop(context, false),
                ),
                const SizedBox(width: 8),
                NgButton(
                  label: 'Log In',
                  icon: 'key',
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
