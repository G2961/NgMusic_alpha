import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NgAuth {
  static const _cookieKey = 'ng_session_cookie';
  static const _usernameKey = 'ng_username';
  static const _channel = MethodChannel('ngmusic/cookies');

  /// Reads the FULL native WebView cookie string for newgrounds.com,
  /// including HttpOnly cookies (the real session cookie) that JS can't see.
  static Future<String> readNativeCookies(
      [String url = 'https://www.newgrounds.com']) async {
    try {
      final res = await _channel.invokeMethod<String>('getCookies', {'url': url});
      return res ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Clears all native WebView cookies (used on logout).
  static Future<void> clearNativeCookies() async {
    try {
      await _channel.invokeMethod('clearCookies');
    } catch (_) {}
  }

  /// Returns stored cookie string
  static Future<String?> getCookie() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_cookieKey);
  }

  static Future<String?> getUsername() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_usernameKey);
  }

  static Future<void> save({
    required String cookie,
    String? username,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cookieKey, cookie);
    if (username != null) await p.setString(_usernameKey, username);
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_cookieKey);
    await p.remove(_usernameKey);
    await clearNativeCookies();
  }

  /// Похоже ли строка на сессионные куки Newgrounds.
  ///
  /// ВАЖНО: по одним кукам НЕЛЬЗЯ отличить гостя от вошедшего: NG выдаёт
  /// `newgrounds_session` уже анонимному посетителю. Признак входа — то, что
  /// страница `/account/` отдала имя пользователя (см. `LoginScreen`), а не эта
  /// проверка. Здесь — только грубая валидация сохранённой строки.
  static bool isRealSession(String? cookie) {
    if (cookie == null || cookie.isEmpty) return false;
    if (!cookie.contains('newgrounds_session')) return false;
    return RegExp(r'newgrounds_session=[A-Za-z0-9%._\-+/=]{15,}')
        .hasMatch(cookie);
  }

  static Future<bool> isLoggedIn() async {
    final c = await getCookie();
    return isRealSession(c);
  }

  // ── Локальное состояние отзывов/голосов ─────────────────────────────────
  //
  // NG после голосования УБИРАЕТ votebar со страницы трека, а свою карточку
  // отзыва отдаёт только на `/audio/listen/{id}`. Чтобы в поде Reviews всегда
  // было видно «твой голос» и «твой отзыв», держим их локально как кэш:
  // источник истины — живая страница трека ([NgRepository.getMyReview]),
  // кэш ускоряет отрисовку и хранит голос, который NG больше не показывает.

  static const _votePrefix = 'ng_my_vote_'; // + trackId → '0'..'10' (звёзды*2)
  static const _reviewPrefix = 'ng_my_review_'; // + trackId → JSON карточки

  /// Сохранённый голос: 0..5 звёзд (null — не голосовал).
  static Future<int?> getMyVote(String trackId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('$_votePrefix$trackId');
    if (raw == null) return null;
    return (int.tryParse(raw) ?? 0) ~/ 2;
  }

  static Future<void> saveMyVote(String trackId, int stars) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('$_votePrefix$trackId', '${(stars * 2).clamp(0, 10)}');
  }

  static Future<void> clearMyVote(String trackId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_votePrefix$trackId');
  }

  /// JSON отзыва: {id, body, vote}. [body]/[vote] — текущие значения.
  static Future<Map<String, dynamic>?> getMyReview(String trackId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('$_reviewPrefix$trackId');
    if (raw == null) return null;
    try {
      // Минимальный разбор без dart:convert-импорта: строку пишем сами.
      final id = RegExp(r'"id":"(\d+)"').firstMatch(raw)?.group(1);
      final vote = RegExp(r'"vote":(\d+)').firstMatch(raw)?.group(1);
      final bodyM = RegExp(r'"body":"((?:[^"\\]|\\.)*)"').firstMatch(raw);
      if (id == null) return null;
      return {
        'id': id,
        'vote': vote == null ? null : int.tryParse(vote),
        'body': bodyM == null ? '' : _jsonUnescape(bodyM.group(1)!),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveMyReview(
      String trackId, String reviewId, String body, int? vote) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        '$_reviewPrefix$trackId',
        '{"id":"$reviewId","vote":${vote ?? 'null'},'
        '"body":"${_jsonEscape(body)}"}');
  }

  static Future<void> clearMyReview(String trackId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_reviewPrefix$trackId');
  }

  static String _jsonEscape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '');

  static String _jsonUnescape(String s) => s
      .replaceAll('\\n', '\n')
      .replaceAll('\\"', '"')
      .replaceAll('\\\\', '\\');
}
