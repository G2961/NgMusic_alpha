import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/track.dart';
import '../../data/model/ng_audio_genres.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/ng_chrome.dart';
import '../widgets/ng_retro.dart';
import 'player_screen.dart';
import 'artist_screen.dart';
import 'login_screen.dart';

/// Аудио-портал Newgrounds 2015: чёрная шапка с логотипом и поиском,
/// полоса плашек-разделов (`.navbar`) и под с треками на весь экран.
///
/// Сайдбар жанров (`ul.sideNav`) по умолчанию СКРЫТ — открывается кнопкой
/// слева от поиска (мобильный паттерн NG 2015 «mobile-menu»).
///
/// Портал аудио в 2015 году носил зелёный скин (`body.green`), поэтому все
/// поды и чередование строк здесь — зелёные.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});
  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _idx = 0;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  /// Сайдбар жанров: по умолчанию закрыт.
  bool _menuOpen = false;

  static const _tabs = [
    NgTab.featured,
    NgTab.latest,
    NgTab.popular,
    NgTab.topRated,
  ];

  /// Плашки навбара.
  static const _tabLabels = ['Featured', 'New', 'Popular', 'Top Rated'];

  /// Заголовки подов — как назывались блоки на audio.newgrounds.com.
  static const _podTitles = [
    'Featured Audio',
    "Brand Spankin' New Audio",
    'Popular Audio',
    'Best of the Best',
  ];

  static const _podIcons = ['star', 'audio', 'trophy', 'badge'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    // Слушаем именно `animation`, а не сам контроллер: `index` меняется
    // только когда свайп уже устоялся, и плашка загоралась с задержкой.
    _tab.animation!.addListener(_onTabAnim);
    _tab.addListener(_onTabChanged);
  }

  /// Подсветку ведём от позиции анимации: плашка переключается на
  /// середине жеста, а не после его окончания.
  void _onTabAnim() {
    final i = _tab.animation!.value.round().clamp(0, _tabs.length - 1);
    if (i != _idx && mounted) setState(() => _idx = i);
  }

  void _onTabChanged() {
    if (_tab.indexIsChanging) return;
    context.read<NgViewModel>().setActiveTab(_tabs[_tab.index]);
  }

  @override
  void dispose() {
    _tab.animation?.removeListener(_onTabAnim);
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final vm = context.read<NgViewModel>();
    if (q.trim().isEmpty) {
      vm.clearSearch();
    } else {
      vm.search(q.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Шапка всегда сверху — сайдбар её не перекрывает.
            NgLogoBar(
              username: vm.currentUser?.username,
              avatarUrl: vm.currentUser?.avatarUrl,
              onUserTap: () => _onUserTap(vm),
            ),
            // Ниже шапки: контент + выдвижной сайдбар.
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          // Кнопка-гамбургер: открывает сайдбар жанров.
                          NgIconButton(
                            icon: 'menu',
                            padding: 10,
                            tooltip: 'Browse genres',
                            onTap: () =>
                                setState(() => _menuOpen = !_menuOpen),
                          ),
                          Expanded(
                            child: NgSearchBar(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              searching: vm.isInSearch,
                              onSubmit: _onSearch,
                              onClear: () => _onSearch(''),
                            ),
                          ),
                        ],
                      ),
                      if (!vm.isInSearch)
                        NgNavPlates(
                          labels: _tabLabels,
                          index: _idx,
                          onSelect: (i) => _tab.animateTo(i),
                        ),
                      Expanded(
                        child: vm.isInSearch
                            ? _SearchResults(vm: vm)
                            : TabBarView(
                                controller: _tab,
                                children: [
                                  for (var i = 0; i < _tabs.length; i++)
                                    _TabPage(
                                      tab: _tabs[i],
                                      title: _podTitles[i],
                                      icon: _podIcons[i],
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),

                  // ── Выдвижной сайдбар жанров (плавный, под логотипом) ─
                  // Затемнение появляется только когда меню открыто.
                  if (_menuOpen)
                    ModalBarrier(
                      color: ngBlack.withValues(alpha: 0.72),
                      dismissible: true,
                      onDismiss: () => setState(() => _menuOpen = false),
                    ),
                  // Само меню выезжает слева AnimatedSlide'ом.
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    offset: _menuOpen ? Offset.zero : const Offset(-1, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: ngBlack,
                        child: SizedBox(
                          width: 210,
                          child: _GenreSidebar(
                            onClose: () => setState(() => _menuOpen = false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onUserTap(NgViewModel vm) {
    final user = vm.currentUser;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtistScreen(artist: user.username)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ).then((_) => vm.fetchUser());
    }
  }
}

// ─── Сайдбар жанров (`ul.sideNav` из левой колонки 2015) ──────────────────

class _GenreSidebar extends StatefulWidget {
  final VoidCallback onClose;
  const _GenreSidebar({required this.onClose});

  @override
  State<_GenreSidebar> createState() => _GenreSidebarState();
}

class _GenreSidebarState extends State<_GenreSidebar> {
  /// Раскрытая группа (аккордеон). null — все свёрнуты.
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final activeGenre = vm.genre?.id;

    return Container(
      decoration: const BoxDecoration(
        color: ngBlack,
        border: Border(right: BorderSide(color: ngHairline)),
      ),
      child: Column(
        children: [
          // Шапка меню с кнопкой закрытия.
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(
              color: ngBlack,
              border: Border(bottom: BorderSide(color: ngHairline)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'BROWSE AUDIO',
                    style: TextStyle(
                      fontFamily: ngHeaderFont,
                      fontSize: 14,
                      color: ngGold,
                    ),
                  ),
                ),
                Builder(builder: (_) => NgIconButton(
                  icon: 'close',
                  padding: 8,
                  tooltip: 'Close',
                  onTap: widget.onClose,
                )),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                _SideLink(
                  label: 'Browse All Audio!',
                  bold: true,
                  active: activeGenre == null,
                  onTap: () {
                    // Снять фильтр — вернуть вкладке исходный список.
                    vm.setGenre(null);
                    widget.onClose();
                  },
                ),
                for (final g in NgAudioGenres.groups) ...[
                  _SideLink(
                    label: g.label,
                    expanded: _expanded == g.label,
                    hasChildren: true,
                    onTap: () {
                      setState(() =>
                          _expanded = _expanded == g.label ? null : g.label);
                    },
                  ),
                  if (_expanded == g.label)
                    for (final sub in g.genres)
                      _SideLink(
                        label: sub.label,
                        indent: true,
                        active: activeGenre == sub.id,
                        onTap: () {
                          // Фильтр применяется к активной вкладке.
                          vm.setGenre(sub);
                          widget.onClose();
                        },
                      ),
                ],
                const SizedBox(height: 8),
                const _SideLink(label: 'Audio Forum'),
                const _SideLink(label: 'Voice Acting Forum'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Пункт сайдбара: золотая ссылка на чёрном, при активе — подсвечена.
class _SideLink extends StatelessWidget {
  final String label;
  final bool bold;
  final bool expanded;
  final bool active;
  final bool indent;
  final bool hasChildren;
  final VoidCallback? onTap;

  const _SideLink({
    required this.label,
    this.bold = false,
    this.expanded = false,
    this.active = false,
    this.indent = false,
    this.hasChildren = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          left: indent ? 18 : 8,
          right: 6,
          top: 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF26221A) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? ngGold : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ngHeaderFont,
                  fontSize: indent ? 11 : 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: active ? ngWhite : ngGold,
                ),
              ),
            ),
            if (hasChildren)
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Image.asset(NgTex.a15('arrow-right'),
                    width: 11, height: 11),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Открытие плеера ─────────────────────────────────────────────────────────

void _openPlayer(BuildContext context) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, a, b) => const PlayerScreen(),
      transitionsBuilder: (_, a, b, c) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: c,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    ),
  );
}

// ─── Под с треками (состояние живёт между свайпами) ───────────────────────────

class _TabPage extends StatefulWidget {
  final NgTab tab;
  final String title;
  final String icon;
  const _TabPage({required this.tab, required this.title, required this.icon});
  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NgViewModel>().loadTab(widget.tab);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      context.read<NgViewModel>().loadMoreForTab(widget.tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final vm = context.watch<NgViewModel>();
    final s = vm.stateOf(widget.tab);

    final Widget body;
    if (s.isLoading && s.tracks.isEmpty) {
      body = const SingleChildScrollView(child: NgLoading());
    } else if (s.error != null && s.tracks.isEmpty) {
      body = SingleChildScrollView(
        child: NgNotice(
          text: s.error!,
          icon: 'flag',
          action: NgButton(
            label: 'Retry',
            icon: 'refresh',
            width: 100,
            onPressed: () => vm.reloadTab(widget.tab),
          ),
        ),
      );
    } else if (s.tracks.isEmpty) {
      body = const SingleChildScrollView(
        child: NgNotice(text: 'Nothing here yet.', icon: 'audio'),
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        itemCount: s.tracks.length + (s.isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= s.tracks.length) return const NgLoading(width: 100);
          return _TrackRow(track: s.tracks[i], index: i);
        },
      );
    }

    return NgPod.fill(
      icon: widget.icon,
      // При активном фильтре подписываем жанр — видно, что отфильтровано.
      title: vm.genre == null
          ? widget.title
          : '${widget.title} — ${vm.genre!.label}',
      skin: NgSkin.gold,
      action: NgPlateLink(
        label: vm.genre == null ? 'Reload »' : 'Clear Filter »',
        onTap: () => vm.genre == null
            ? vm.reloadTab(widget.tab)
            : vm.setGenre(null),
      ),
      child: body,
    );
  }
}

// ─── Под с результатами поиска ────────────────────────────────────────────────

class _SearchResults extends StatefulWidget {
  final NgViewModel vm;
  const _SearchResults({required this.vm});
  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        widget.vm.loadMoreSearch();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    final Widget body;
    if (vm.isSearching && vm.searchResults.isEmpty) {
      body = const SingleChildScrollView(child: NgLoading());
    } else if (vm.searchError != null && vm.searchResults.isEmpty) {
      body = SingleChildScrollView(
        child: NgNotice(text: vm.searchError!, icon: 'flag'),
      );
    } else if (vm.searchResults.isEmpty) {
      body = const SingleChildScrollView(
        child: NgNotice(text: 'No results.', icon: 'search'),
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        itemCount: vm.searchResults.length + (vm.isSearching ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= vm.searchResults.length) return const NgLoading(width: 100);
          return _TrackRow(track: vm.searchResults[i], index: i);
        },
      );
    }

    return NgPod.fill(
      icon: 'search',
      title: 'Search Results',
      skin: NgSkin.gold,
      child: body,
    );
  }
}

// ─── Строка `table.audiolist tr` ──────────────────────────────────────────────

class _TrackRow extends StatelessWidget {
  final Track track;
  final int index;
  const _TrackRow({required this.track, required this.index});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final isActive = vm.currentTrack?.id == track.id;

    return NgAudioRow(
      index: index,
      skin: NgSkin.gold,
      iconUrl: track.aIconUrl,
      title: track.title,
      genre: track.genre,
      artist: track.artist,
      playing: isActive,
      paused: isActive && !vm.isPlaying,
      onTap: () {
        // Играем в пределах текущего списка (таб или поиск) — очередь артиста сбрасываем.
        vm.setQueueContext(null);
        vm.playTrack(track);
        _openPlayer(context);
      },
      onArtistTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtistScreen(artist: track.artist)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.duration > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(_fmt(track.duration), style: ngLabel),
            ),
          _TrackActions(track: track),
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

// ─── Иконки действий (избранное + плейлист) ───────────────────────────────────

class _TrackActions extends StatelessWidget {
  final Track track;
  const _TrackActions({required this.track});

  @override
  Widget build(BuildContext context) {
    final lvm = context.watch<LibraryViewModel>();
    final vm = context.watch<NgViewModel>();
    final isFav = lvm.isFavorite(track.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NgIconButton(
          icon: isFav ? 'fav-on' : 'fav-add',
          padding: 5,
          tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
          onTap: () => _onFavTap(context, vm, lvm),
        ),
        NgIconButton(
          icon: 'playlist',
          padding: 5,
          tooltip: 'Add to playlist',
          onTap: () => showAddToPlaylistSheet(context, track),
        ),
      ],
    );
  }

  Future<void> _onFavTap(
      BuildContext context, NgViewModel vm, LibraryViewModel lvm) async {
    if (vm.currentUser == null) {
      final doLogin = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: ngPodBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            side: BorderSide(color: ngPodBorder, width: 4),
          ),
          title: const Text('Login Required', style: ngH2),
          content: const Text('Log in to save favorites.', style: ngBody),
          actionsPadding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
          actions: [
            NgButton(
              label: 'Cancel',
              width: 90,
              onPressed: () => Navigator.pop(context, false),
            ),
            NgButton(
              label: 'Login',
              icon: 'key',
              width: 96,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (doLogin == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (context.mounted) await vm.fetchUser();
      }
      return;
    }
    await lvm.toggleFavorite(track);
  }
}
