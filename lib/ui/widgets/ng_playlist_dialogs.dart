import 'package:flutter/material.dart';

import '../../viewmodel/library_viewmodel.dart';
import '../theme/ng_theme.dart';
import 'ng_retro.dart';

/// Диалог «новый плейлист» в вёрстке 2015: под с полем ввода и выбором места.
///
/// Живёт отдельно от экранов, потому что нужен в двух местах: кнопка
/// «+ Playlist» в библиотеке и «+ New» во всплывашке добавления трека.

/// Результат диалога создания: имя и место хранения.
class NgNewPlaylist {
  final String name;
  final PlaylistTarget target;
  const NgNewPlaylist(this.name, this.target);
}

/// Показывает диалог создания. Возвращает null, если отменили.
///
/// [canUseNg] == false — вариант Newgrounds виден, но заблокирован: так
/// понятно, чего не хватает. [target] задаёт предвыбранное место.
Future<NgNewPlaylist?> showNgCreatePlaylistDialog(
  BuildContext context, {
  required bool canUseNg,
  PlaylistTarget target = PlaylistTarget.local,
  NgSkin skin = NgSkin.gold,
}) {
  return showDialog<NgNewPlaylist>(
    context: context,
    barrierColor: ngBlack.withValues(alpha: 0.72),
    builder: (_) => _CreatePlaylistDialog(
      canUseNg: canUseNg,
      initialTarget: target,
      skin: skin,
    ),
  );
}

class _CreatePlaylistDialog extends StatefulWidget {
  final bool canUseNg;
  final PlaylistTarget initialTarget;
  final NgSkin skin;

  const _CreatePlaylistDialog({
    required this.canUseNg,
    required this.initialTarget,
    required this.skin,
  });

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late PlaylistTarget _target =
      widget.canUseNg ? widget.initialTarget : PlaylistTarget.local;

  @override
  void initState() {
    super.initState();
    // У NgTextField нет autofocus — поднимаем клавиатуру после первого кадра.
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
    if (name.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, NgNewPlaylist(name, _target));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: NgPod(
        icon: 'list',
        title: 'New Playlist',
        skin: widget.skin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Playlist name', style: ngLabel),
            const SizedBox(height: 5),
            NgTextField(
              controller: _ctrl,
              focusNode: _focus,
              hint: 'My Mixtape',
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            const Text('Where to create', style: ngLabel),
            const SizedBox(height: 5),
            NgTargetRow(
              icon: 'folder',
              label: 'This app',
              hint: 'Stays on the phone.',
              skin: widget.skin,
              selected: _target == PlaylistTarget.local,
              onTap: () => setState(() => _target = PlaylistTarget.local),
            ),
            NgTargetRow(
              icon: 'pico',
              label: 'Newgrounds',
              hint: widget.canUseNg
                  ? 'Created on your NG account.'
                  : 'Log in to use this.',
              skin: widget.skin,
              selected: _target == PlaylistTarget.newgrounds,
              enabled: widget.canUseNg,
              onTap: () => setState(() => _target = PlaylistTarget.newgrounds),
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
                NgButton(label: 'Create', icon: 'add', onPressed: _submit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка выбора места создания: иконка, подпись, галочка выбора.
class NgTargetRow extends StatelessWidget {
  final String icon;
  final String label;
  final String hint;
  final bool selected;
  final bool enabled;
  final NgSkin skin;
  final VoidCallback onTap;

  const NgTargetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
    this.skin = NgSkin.gold,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? skin.podtopFill : ngBlack,
            border: Border.all(color: selected ? ngGreen : ngHairline),
          ),
          child: Row(
            children: [
              Image.asset(NgTex.h2(icon), width: 20, height: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: ngLink),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(hint, style: ngLabel),
                    ),
                  ],
                ),
              ),
              if (selected)
                Image.asset(NgTex.a15('check'), width: 15, height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
