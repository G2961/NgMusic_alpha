import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/playlist.dart';
import '../../data/repository/local_db.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/ng_chrome.dart';
import '../widgets/ng_playlist_dialogs.dart';
import '../widgets/ng_retro.dart';
import 'artist_screen.dart';
import 'login_screen.dart';
import 'player_screen.dart';
import 'playlist_screen.dart';

/// Библиотека в вёрстке Newgrounds 2015: полоса плашек `.navbar` вместо
/// переключателя вкладок и один под (`#main>div`) на весь экран, внутри —
/// строки `table.audiolist tr`.
///
/// Аудио-портал 2015 носил зелёный скин (`body.green`), поэтому поды и
/// чередование строк здесь зелёные — как в хабе.
const _skin = NgSkin.gold;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _idx = 0;

  static const _tabLabels = ['Playlists', 'Favorites'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabLabels.length, vsync: this);
    // Подсветка от позиции анимации, а не от `index`: тот меняется только
    // когда свайп устоялся, и плашка загоралась с задержкой.
    _tab.animation!.addListener(_onTabAnim);
  }

  void _onTabAnim() {
    final i = _tab.animation!.value.round().clamp(0, _tabLabels.length - 1);
    if (i != _idx && mounted) setState(() => _idx = i);
  }

  @override
  void dispose() {
    _tab.animation?.removeListener(_onTabAnim);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lvm = context.watch<LibraryViewModel>();
    final vm = context.watch<NgViewModel>();

    // Ошибки операций с NG показываем снеком: тихо проглатывать их было
    // главной причиной «ничего не работает, но и не ругается».
    final error = lvm.lastError;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<LibraryViewModel>().clearError();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(error, style: const TextStyle(color: ngWhite, fontSize: 12)),
          backgroundColor: ngRed,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(),
        ));
      });
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NgNavPlates(
              labels: _tabLabels,
              index: _idx,
              onSelect: (i) => _tab.animateTo(i),
              accents: const [NgAccent.blue, NgAccent.red],
            ),
            Expanded(
              child: NgPageColumn(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _PlaylistsTab(lvm: lvm, onCreate: _showCreatePlaylist),
                    _FavoritesTab(lvm: lvm, vm: vm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Новый плейлист: имя + выбор, где его создать. Вариант Newgrounds
  /// доступен только после входа. Сам диалог общий со всплывашкой
  /// добавления трека — см. `ng_playlist_dialogs.dart`.
  Future<void> _showCreatePlaylist() async {
    final lvm = context.read<LibraryViewModel>();
    final result = await showNgCreatePlaylistDialog(
      context,
      canUseNg: lvm.isLoggedIn,
      skin: _skin,
    );
    if (result == null || !mounted) return;
    await lvm.createPlaylist(result.name, target: result.target);
  }
}

// ─── Вкладка «Playlists» ──────────────────────────────────────────

class _PlaylistsTab extends StatelessWidget {
  final LibraryViewModel lvm;
  final VoidCallback onCreate;
  const _PlaylistsTab({required this.lvm, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final local = lvm.localPlaylists;
    final ng = lvm.ngPlaylists;

    final Widget body;
    if (lvm.isLoading && lvm.playlists.isEmpty) {
      body = const SingleChildScrollView(child: NgLoading());
    } else if (lvm.playlists.isEmpty) {
      body = SingleChildScrollView(
        child: NgNotice(
          text: 'No playlists yet.',
          icon: 'folder',
          action: NgButton(
            label: 'New Playlist',
            icon: 'add',
            onPressed: onCreate,
          ),
        ),
      );
    } else {
      body = ListView(
        padding: EdgeInsets.zero,
        children: [
          if (lvm.isSyncingNg) const NgLoading(width: 100),
          if (local.isNotEmpty)
            NgSection(
              label: 'Local',
              icon: 'folder',
              count: local.length,
              collapsed: lvm.isCollapsed(LibrarySection.local),
              onToggle: () => lvm.toggleSection(LibrarySection.local),
              children: [
                for (var i = 0; i < local.length; i++)
                  _PlaylistRow(index: i, playlist: local[i], lvm: lvm),
              ],
            ),
          if (ng.isNotEmpty)
            NgSection(
              label: 'Newgrounds',
              icon: 'pico',
              count: ng.length,
              collapsed: lvm.isCollapsed(LibrarySection.newgrounds),
              onToggle: () => lvm.toggleSection(LibrarySection.newgrounds),
              children: [
                for (var i = 0; i < ng.length; i++)
                  _PlaylistRow(index: i, playlist: ng[i], lvm: lvm),
              ],
            ),
        ],
      );
    }

    return NgPod.fill(
      icon: 'list',
      title: 'Your Playlists',
      skin: _skin,
      action: NgPlateLink(label: '+ Playlist »', onTap: onCreate),
      child: body,
    );
  }
}

/// Строка плейлиста: иконка папки (локальный) или Пико (зеркало NG).
class _PlaylistRow extends StatelessWidget {
  final int index;
  final Playlist playlist;
  final LibraryViewModel lvm;
  const _PlaylistRow({
    required this.index,
    required this.playlist,
    required this.lvm,
  });

  @override
  Widget build(BuildContext context) {
    final desc = playlist.description;
    return NgListRow(
      index: index,
      skin: _skin,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: lvm,
            child: PlaylistScreen(playlist: playlist),
          ),
        ),
      ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.name,
                    style: ngLink,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (desc != null && desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        desc,
                        style: ngLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Image.asset(NgTex.a15('arrow-right'), width: 15, height: 15),
          ],
        ),
      ),
    );
  }
}

// ─── Вкладка «Favorites» ──────────────────────────────────────────────────────

class _FavoritesTab extends StatelessWidget {
  final LibraryViewModel lvm;
  final NgViewModel vm;
  const _FavoritesTab({required this.lvm, required this.vm});

  @override
  Widget build(BuildContext context) {
    final local = lvm.localFavorites;
    final ng = lvm.ngFavorites;

    final Widget body;
    if (!lvm.isLoggedIn && lvm.favorites.isEmpty) {
      body = SingleChildScrollView(
        child: NgNotice(
          text: 'Log in to see your favorites.',
          icon: 'user',
          action: NgButton(
            label: 'Log In',
            icon: 'key',
            onPressed: () => _login(context),
          ),
        ),
      );
    } else if (lvm.isLoading && lvm.favorites.isEmpty) {
      body = const SingleChildScrollView(child: NgLoading());
    } else if (lvm.favorites.isEmpty) {
      body = const SingleChildScrollView(
        child: NgNotice(
          text: 'No favorites yet.\nTap the heart on any track to save it.',
          icon: 'heart',
        ),
      );
    } else {
      // Сердечки приложения и сердечки аккаунта NG — разные списки: первые
      // живут только в базе, вторые есть и на сайте (см. LocalDb, колонка is_ng).
      body = ListView(
        padding: EdgeInsets.zero,
        children: [
          if (local.isNotEmpty)
            NgSection(
              label: 'This app',
              icon: 'heart',
              count: local.length,
              collapsed: lvm.isCollapsed(LibrarySection.favLocal),
              onToggle: () => lvm.toggleSection(LibrarySection.favLocal),
              children: [
                for (var i = 0; i < local.length; i++)
                  _FavoriteRow(
                    index: i,
                    favorite: local[i],
                    queue: local,
                    lvm: lvm,
                    vm: vm,
                  ),
              ],
            ),
          if (ng.isNotEmpty)
            NgSection(
              label: 'Newgrounds',
              icon: 'pico',
              count: ng.length,
              collapsed: lvm.isCollapsed(LibrarySection.favNewgrounds),
              onToggle: () => lvm.toggleSection(LibrarySection.favNewgrounds),
              children: [
                for (var i = 0; i < ng.length; i++)
                  _FavoriteRow(
                    index: i,
                    favorite: ng[i],
                    queue: ng,
                    lvm: lvm,
                    vm: vm,
                  ),
              ],
            ),
        ],
      );
    }

    return NgPod.fill(
      icon: 'heart',
      title: 'Your Favorites',
      skin: _skin,
      action: NgPlateLink(label: 'Refresh »', onTap: lvm.refresh),
      child: body,
    );
  }

  Future<void> _login(BuildContext context) async {
    final username = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (username == null || !context.mounted) return;
    await vm.fetchUser();
    if (!context.mounted) return;
    await context.read<LibraryViewModel>().syncNgPlaylists(username);
  }
}

class _FavoriteRow extends StatelessWidget {
  final int index;
  final Favorite favorite;

  /// Очередь плеера — только та секция, в которой нажали.
  final List<Favorite> queue;
  final LibraryViewModel lvm;
  final NgViewModel vm;
  const _FavoriteRow({
    required this.index,
    required this.favorite,
    required this.queue,
    required this.lvm,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final track = LocalDb.favoriteToTrack(favorite);
    final isActive = vm.currentTrack?.id == favorite.trackId;

    return NgAudioRow(
      index: index,
      skin: _skin,
      iconUrl: favorite.iconUrl,
      title: favorite.title,
      genre: favorite.genre ?? '',
      artist: favorite.artist,
      playing: isActive,
      paused: isActive && !vm.isPlaying,
      onTap: () {
        vm.setQueueContext(queue.map(LocalDb.favoriteToTrack).toList());
        vm.playTrack(track);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayerScreen()),
        );
      },
      onArtistTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ArtistScreen(artist: favorite.artist)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (favorite.duration > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(_fmt(favorite.duration), style: ngLabel),
            ),
          NgIconButton(
            icon: 'fav-on',
            padding: 5,
            tooltip: 'Remove from favorites',
            onTap: () => lvm.toggleFavorite(track),
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
