import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/ng_user.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/ng_chrome.dart';
import '../widgets/ng_retro.dart';
import '../../main.dart' show NgMiniPlayer;
import 'artist_screen.dart';
import 'login_screen.dart';

/// Страница аккаунта в вёрстке Newgrounds 2015: чёрная шапка с логотипом,
/// серая колонка `#main` и поды — `Account` (аватар, ник, `table.itemdetails`)
/// и `Settings` (строки `table.audiolist tr` с кнопками справа).
///
/// Аудио-портал 2015 носил зелёный скин (`body.green`) — поды здесь зелёные,
/// как в хабе и плеере.
const _skin = NgSkin.gold;

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _idx = 0;

  static const _tabLabels = ['Account', 'Settings'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabLabels.length, vsync: this);
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
    final vm = context.watch<NgViewModel>();
    final user = vm.currentUser;
    final landscape = MediaQuery.of(context).size.width >
        MediaQuery.of(context).size.height;

    final Widget content;
    if (vm.isLoadingUser && user == null) {
      content = const NgPod(
        icon: 'user',
        title: 'Account',
        skin: _skin,
        child: NgLoading(),
      );
    } else if (user == null) {
      content = _LoggedOutPod(onLogin: _login);
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfilePod(
            user: user,
            refreshing: vm.isLoadingUser,
            onRefresh: vm.fetchUser,
            onLogout: _logout,
            onOpenProfile: () => _openProfile(user.username),
          ),
          if (!landscape) _SettingsPod(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NgLogoBar(
              username: user?.username,
              avatarUrl: user?.avatarUrl,
              onUserTap:
                  user == null ? _login : () => _openProfile(user.username),
            ),
            Expanded(
              // Ландшафт: слева стопка вкладок Account/Settings + мини-плеер,
              // справа контент выбранной вкладки (свайпов нет). Портрет:
              // обычная колонка подов, настройки — под профилем.
              child: landscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedBuilder(
                          animation: _tab.animation!,
                          builder: (_, __) => Column(
                            children: [
                              NgNavPlatesSide(
                                labels: _tabLabels,
                                index: _idx,
                                onSelect: (i) => _tab.animateTo(i),
                                accents: const [NgAccent.orange, NgAccent.purple],
                                progress:
                                    _tab.animation?.value ?? _idx.toDouble(),
                              ),
                              const Spacer(),
                              if (vm.currentTrack != null)
                                const SizedBox(
                                  width: 170,
                                  child: NgMiniPlayer(compact: true),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(left: 8, right: 6, top: 8),
                            child: _pane(landscape, content),
                          ),
                        ),
                      ],
                    )
                  : NgPageColumn(
                      padding: EdgeInsets.zero,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [content],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Действия ───────────────────────────────────────────────────────────────

  /// Контент правой панели в ландшафте: вкладка [i] — отдельный «экран».
  /// Когда пользователь не вошёл, обе вкладки показывают под логина.
  Widget _pane(bool landscape, Widget loggedOutOrLoading) {
    final vm = context.read<NgViewModel>();
    final user = vm.currentUser;
    if (_idx == 0 || user == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [loggedOutOrLoading],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const _SettingsPod()],
      ),
    );
  }

  Future<void> _login() async {
    final vm = context.read<NgViewModel>();
    final lvm = context.read<LibraryViewModel>();

    final username = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (username == null || username.isEmpty || !mounted) return;

    await vm.fetchUser();
    if (!mounted) return;
    await lvm.syncNgPlaylists(username);
  }

  Future<void> _logout() async {
    final vm = context.read<NgViewModel>();
    final lvm = context.read<LibraryViewModel>();

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: ngBlack.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: NgPod(
          icon: 'power',
          title: 'Log Out',
          skin: _skin,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Are you sure you want to log out?', style: ngBody),
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
                    label: 'Log Out',
                    icon: 'power',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    await vm.logout();
    if (!mounted) return;
    await lvm.clearNgPlaylists();
    if (!mounted) return;
    // Экран живёт и как вкладка `IndexedStack`, и как отдельный роут —
    // `maybePop` закрывает только второй случай.
    Navigator.maybePop(context);
  }

  void _openProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArtistScreen(artist: username)),
    );
  }
}

// ── Не вошёл ─────────────────────────────────────────────────────────────────

class _LoggedOutPod extends StatelessWidget {
  final VoidCallback onLogin;
  const _LoggedOutPod({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return NgPod(
      icon: 'user',
      title: 'Account',
      skin: _skin,
      child: NgNotice(
        text: 'You are not logged in.\n'
            'Log in with your Newgrounds account to sync\n'
            'favorites and playlists with the site.',
        action: NgButton(
          label: 'Log In',
          icon: 'key',
          width: 116,
          onPressed: onLogin,
        ),
      ),
    );
  }
}

// ── Вошёл: аватар, ник, кнопки, `table.itemdetails` ──────────────────────────

class _ProfilePod extends StatelessWidget {
  final NgUser user;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final VoidCallback onOpenProfile;

  const _ProfilePod({
    required this.user,
    required this.refreshing,
    required this.onRefresh,
    required this.onLogout,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final lvm = context.watch<LibraryViewModel>();

    return NgPod.list(
      icon: 'user',
      title: 'Account',
      skin: _skin,
      action: NgPlateLink(label: 'Profile »', onTap: onOpenProfile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: onOpenProfile,
                        child: _SquareAvatar(url: user.avatarUrl),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: onOpenProfile,
                              child: Text(
                                user.username,
                                style: ngLink.copyWith(fontSize: 18),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(_caption, style: ngLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    NgButton(
                      label: refreshing ? 'Refreshing…' : 'Refresh',
                      icon: 'refresh',
                      onPressed: refreshing ? null : onRefresh,
                    ),
                    NgButton(
                      label: 'Log Out',
                      icon: 'power',
                      onPressed: onLogout,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const NgPodBreaker(),
          NgInfoTable(items: _rows(lvm), skin: _skin, labelWidth: 84),
        ],
      ),
    );
  }

  /// Подпись под ником: уровень, если профиль его отдал.
  String get _caption =>
      user.level != null ? 'Level ${user.level}' : 'Newgrounds member';

  List<NgInfoItem> _rows(LibraryViewModel lvm) => [
        NgInfoItem('Username', user.username),
        if (user.level != null) NgInfoItem('Level', user.level!),
        if (user.exp != null) NgInfoItem('EXP', user.exp!),
        if (user.fans != null) NgInfoItem('Fans', user.fans!),
        if (user.audioCount != null) NgInfoItem('Audio', user.audioCount!),
        if (user.age != null) NgInfoItem('Age', user.age!),
        if (user.gender != null) NgInfoItem('Gender', user.gender!),
        if (user.country != null) NgInfoItem('Country', user.country!),
        if (user.joinDate != null) NgInfoItem('Joined', user.joinDate!),
        NgInfoItem('Favorites', _favorites(lvm)),
        NgInfoItem('Playlists', _playlists(lvm)),
      ];

  String _tracks(int n) => n == 1 ? '1 track' : '$n tracks';

  String _favorites(LibraryViewModel lvm) {
    final total = lvm.favorites.length;
    if (total == 0) return 'none yet';
    final fromNg = lvm.ngFavorites.length;
    return fromNg == 0
        ? '${_tracks(total)} in app'
        : '${_tracks(total)} ($fromNg on NG)';
  }

  String _playlists(LibraryViewModel lvm) {
    final total = lvm.playlists.length;
    if (total == 0) return 'none yet';
    final fromNg = lvm.ngPlaylists.length;
    return fromNg == 0 ? '$total local' : '$total ($fromNg from NG)';
  }
}

/// Аватар 2015 — квадрат в рамке, без скруглений.
class _SquareAvatar extends StatelessWidget {
  final String? url;
  const _SquareAvatar({this.url});

  /// `div.podtop`-аватарки 2015 — 58×58 в рамке 1px.
  static const _size = 58.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: const BoxDecoration(
        color: ngBlack,
        border: Border.fromBorderSide(BorderSide(color: ngBrown)),
      ),
      child: url == null || url!.isEmpty
          ? Center(child: Image.asset(NgTex.h2('user'), width: 31, height: 31))
          : NgTrackIcon(url: url!, size: _size - 2),
    );
  }
}

// ── Настройки ────────────────────────────────────────────────────────────────

class _SettingsPod extends StatelessWidget {
  const _SettingsPod();

  @override
  Widget build(BuildContext context) {
    final lvm = context.watch<LibraryViewModel>();
    final target = lvm.favTarget;

    void select(FavoriteSaveTarget t) =>
        context.read<LibraryViewModel>().setFavTarget(t);

    return NgPod.list(
      icon: 'gear',
      title: 'Settings',
      skin: _skin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(11, 2, 11, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Save favorites to', style: ngH3),
                SizedBox(height: 4),
                Text(
                  'Choose whether the heart button saves tracks only in this '
                  'app, or to your real Newgrounds favorites.',
                  style: ngBodySmall,
                ),
              ],
            ),
          ),
          _OptionRow(
            index: 0,
            label: 'This App',
            hint: 'Hearts stay in NGMusic.',
            selected: target == FavoriteSaveTarget.local,
            onSelect: () => select(FavoriteSaveTarget.local),
          ),
          _OptionRow(
            index: 1,
            label: 'Newgrounds',
            hint: 'Hearts go to your NG favorites.',
            selected: target == FavoriteSaveTarget.newgrounds,
            onSelect: () => select(FavoriteSaveTarget.newgrounds),
          ),
        ],
      ),
    );
  }
}

/// Строка-переключатель: подпись слева, кнопка выбора справа. Выбранный
/// вариант подсвечен фоном шапки пода, кнопка у него погашена.
class _OptionRow extends StatelessWidget {
  final int index;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onSelect;

  const _OptionRow({
    required this.index,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return NgListRow(
      index: index,
      skin: _skin,
      highlight: selected,
      onTap: selected ? null : onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: selected ? ngLink.copyWith(color: ngWhite) : ngLink,
                  ),
                  const SizedBox(height: 2),
                  Text(hint, style: ngLabel),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected)
              const NgButton(label: 'Active', width: 92)
            else
              NgButton(
                label: 'Use This',
                width: 92,
                onPressed: onSelect,
              ),
          ],
        ),
      ),
    );
  }
}
