import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/model/track.dart';
import '../data/repository/ng_repository.dart';
import '../ui/theme/ng_theme.dart';

class TrackDownloader {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';
  static final _repo = NgRepository();

  static Future<void> download(Track track, BuildContext context) async {
    // Resolve the CDN mp3 URL on demand — no need to play the track first.
    var url = track.mp3Url;
    if (url == null || url.isEmpty) {
      try {
        await _repo.enrichTrack(track);
        url = track.mp3Url;
      } catch (_) {}
    }
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        _snack(context, 'Не удалось получить ссылку на трек', isError: true);
      }
      return;
    }

    final savePath = await _resolveDir(context);
    if (savePath == null) return;

    final filename = _sanitize('${track.artist} - ${track.title}.mp3');
    final file = File('$savePath/$filename');

    if (await file.exists()) {
      _snack(context, 'Уже скачан: $filename');
      return;
    }

    try {
      _snack(context, 'Скачивание…');
      final res = await http.get(Uri.parse(url),
          headers: {'User-Agent': _ua}).timeout(const Duration(minutes: 5));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      await file.writeAsBytes(res.bodyBytes);
      if (context.mounted) {
        _snack(context, 'Сохранено в Downloads: $filename');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Ошибка скачивания: $e', isError: true);
      }
    }
  }

  static Future<String?> _resolveDir(BuildContext context) async {
    if (Platform.isAndroid) {
      // Android 11+ needs MANAGE_EXTERNAL_STORAGE to write to public Downloads.
      // Older versions use the legacy WRITE_EXTERNAL_STORAGE.
      final granted = await _ensureStoragePermission(context);
      if (granted) {
        final pub = Directory('/storage/emulated/0/Download/NGMusic');
        try {
          await pub.create(recursive: true);
          // Verify we can actually write
          final probe = File('${pub.path}/.probe');
          await probe.writeAsString('ok');
          await probe.delete();
          return pub.path;
        } catch (_) {}
      }
    }

    // Fallback: app-private external storage (always writable, no permission)
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/Downloads');
        await dir.create(recursive: true);
        if (context.mounted) {
          _snack(context,
              'Нет доступа к Downloads — сохраняю внутри приложения',
              isError: true);
        }
        return dir.path;
      }
    } catch (_) {}

    if (context.mounted) {
      _snack(context, 'Нет доступа к хранилищу', isError: true);
    }
    return null;
  }

  /// Requests the right storage permission for the platform version.
  static Future<bool> _ensureStoragePermission(BuildContext context) async {
    // Try the modern "all files access" first (Android 11+).
    var manage = await Permission.manageExternalStorage.status;
    if (manage.isGranted) return true;

    // Legacy storage permission (Android 10 and below grants real access).
    final legacy = await Permission.storage.request();
    if (legacy.isGranted) return true;

    // Need MANAGE_EXTERNAL_STORAGE — this opens a system settings screen.
    manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;

    if (manage.isPermanentlyDenied && context.mounted) {
      final open = await _askOpenSettings(context);
      if (open == true) {
        await openAppSettings();
        // Re-check after returning from settings
        manage = await Permission.manageExternalStorage.status;
        return manage.isGranted;
      }
    }
    return false;
  }

  static Future<bool?> _askOpenSettings(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cSurface2,
        title: const Text('Нужно разрешение',
            style: TextStyle(color: cTextPri, fontSize: 17)),
        content: const Text(
          'Чтобы сохранять треки в папку Downloads, дай приложению доступ '
          '«Управление всеми файлами» в настройках.',
          style: TextStyle(color: cTextSec, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: cTextDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Открыть настройки',
                style: TextStyle(color: cAccent)),
          ),
        ],
      ),
    );
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');

  static void _snack(BuildContext context, String msg,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade800 : null,
      duration: Duration(seconds: isError ? 4 : 2),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
