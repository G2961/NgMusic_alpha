import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'player/ng_audio_handler.dart';
import 'ui/screens/hub_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/account_screen.dart';
import 'ui/screens/player_screen.dart';
import 'ui/theme/ng_theme.dart';
import 'ui/widgets/ng_chrome.dart';
import 'ui/widgets/ng_retro.dart';

import 'viewmodel/ng_viewmodel.dart';
import 'viewmodel/library_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NgMusicApp(handler: NgAudioHandler()));
}

class NgMusicApp extends StatelessWidget {
  final NgAudioHandler handler;
  const NgMusicApp({super.key, required this.handler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NgViewModel(handler)),
        ChangeNotifierProvider(create: (_) => LibraryViewModel()),
      ],
      child: MaterialApp(
        title: 'NGMusic',
        theme: ngTheme,
        home: const _RootShell(),
      ),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();
  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _idx = 0;
  String? _lastSyncedUser;

  static const _screens = [
    HubScreen(),
    LibraryScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final lvm = context.read<LibraryViewModel>();
    final hasPlayer = vm.currentTrack != null;

    // Sync NG playlists when user logs in
    final user = vm.currentUser;
    if (user != null && user.username != _lastSyncedUser) {
      _lastSyncedUser = user.username;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        lvm.syncNgPlaylists(user.username);
      });
    } else if (user == null && _lastSyncedUser != null) {
      _lastSyncedUser = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        lvm.clearNgPlaylists();
      });
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPlayer) _MiniPlayerBar(vm: vm),
          NgBottomNav(index: _idx, onSelect: (i) => setState(() => _idx = i)),
        ],
      ),
    );
  }
}

// ─── Мини-плеер над нижней навигацией ───────────────────────────

/// Мини-плеер 2024: плоская тёмная полоса, транспорт слева, центр —
/// название/автор, справа heart и время; снизу тонкий оранжевый
/// прогресс (вместо полосок 2015). Порядок кнопок прежний.
/// Во время загрузки трека вместо прогресса бежит сегмент-индикатор.
class _MiniPlayerBar extends StatefulWidget {
  final NgViewModel vm;
  const _MiniPlayerBar({required this.vm});

  @override
  State<_MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<_MiniPlayerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _load;

  @override
  void initState() {
    super.initState();
    // Бегущая полоска загрузки: цикл 700ms, как в 2024-дизайне NG.
    _load = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final track = vm.currentTrack!;
    final dur = vm.duration;
    final progress = (dur != null && dur.inMilliseconds > 0)
        ? (vm.position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final lvm = context.watch<LibraryViewModel>();
    final isFav = lvm.isFavorite(track.id);

    // Тикер бежит только пока трек грузится — батарея не тратится.
    if (vm.isLoadingTrack && !_load.isAnimating) _load.repeat();
    if (!vm.isLoadingTrack && _load.isAnimating) _load.stop();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, b) => const PlayerScreen(),
          transitionsBuilder: (_, a, b, c) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: c,
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            color: ngPodBg,
            padding: const EdgeInsets.only(left: 6, right: 4),
            child: Row(
              children: [
                // Обложка-диск слева (как было).
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: NgTrackIcon(url: track.aIconUrl, size: 42, oval: true),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          style: const TextStyle(
                              fontFamily: 'Arial',
                              color: ngWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(track.artist,
                          style: ngLink.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Транспорт справа — плоские иконки, прежний порядок.
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.skip_previous,
                      size: 22, color: ngText),
                  onPressed: vm.hasPrev() ? vm.playPrev : null,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    vm.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 26,
                    color: ngWhite,
                  ),
                  onPressed:
                      vm.isLoadingTrack ? null : vm.togglePlayPause,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon:
                      const Icon(Icons.skip_next, size: 22, color: ngText),
                  onPressed: vm.hasNext() ? vm.playNext : null,
                ),
                // Heart — статус любимого, крайний справа.
                GestureDetector(
                  onTap: () => lvm.toggleFavorite(track),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: isFav ? ngRed : ngDim,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Прогресс — тонкая линия (2024). Во время загрузки вместо
          // статичной полосы бежит сегмент-индикатор (indeterminate).
          SizedBox(
            height: 3,
            width: double.infinity,
            child: vm.isLoadingTrack
                ? AnimatedBuilder(
                    animation: _load,
                    builder: (context, _) {
                      final t = _load.value;
                      // Ведущий край выбегает слева за первые 60% цикла,
                      // хвост догоняет справа — сегмент «протекает» по полосе.
                      final head = t < 0.6
                          ? Curves.easeOutCubic.transform(t / 0.6)
                          : 1.0;
                      final tail = t < 0.4
                          ? 0.0
                          : Curves.easeInCubic.transform((t - 0.4) / 0.6);
                      // Позиция сегмента: центр (head+tail)/2, ширина head-tail;
                      // минимум 4%, чтобы индикатор не исчезал на краях цикла.
                      final width = (head - tail).clamp(0.04, 1.0);
                      final center = (head + tail) / 2;
                      final x = ((center * 2 - 1) / (1 - width))
                          .clamp(-1.0, 1.0);
                      return ColoredBox(
                        color: ngHairline,
                        child: FractionallySizedBox(
                          alignment: Alignment(x, 0),
                          widthFactor: width,
                          child: const ColoredBox(color: ngPlayerYellow),
                        ),
                      );
                    },
                  )
                : LinearProgressIndicator(
                    value: progress,
                    backgroundColor: ngHairline,
                    color: ngPlayerYellow,
                    minHeight: 3,
                  ),
          ),
        ],
      ),
    );
  }
}

