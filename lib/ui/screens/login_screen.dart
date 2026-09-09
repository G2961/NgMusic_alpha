import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/repository/ng_auth.dart';
import '../theme/ng_theme.dart';
import '../widgets/ng_retro.dart';

/// Аудио-портал 2015 носил зелёный скин (`body.green`).
const _skin = NgSkin.gold;

/// Вход через Newgrounds Passport: сам паспорт остаётся веб-страницей, но
/// обрамление — шапка с логотипом и под (`#main>div`) со состояниями загрузки
/// и ошибки в вёрстке 2015.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _done = false;
  bool _extracting = false;
  bool _onPassportPage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (!_extracting) setState(() => _loading = true);
        },
        onPageFinished: (url) async {
          setState(() => _loading = false);
          debugPrint('[ng-login] finished: $url '
              '(passport=$_onPassportPage extracting=$_extracting done=$_done)');
          if (_done) return;

          if (url.contains('/passport')) {
            setState(() => _onPassportPage = true);
            return;
          }

          // Ушли с паспорта на домен NG — вероятно, вход удался
          if (_onPassportPage &&
              url.contains('newgrounds.com') &&
              !_extracting &&
              !_done) {
            await _onDone();
            return;
          }

          if (_extracting && url.contains('newgrounds.com')) {
            await _doExtract();
          }
        },
      ))
      ..loadRequest(Uri.parse('https://www.newgrounds.com/passport/'));
  }

  Future<void> _onDone() async {
    if (_done || _extracting) return;
    setState(() {
      _extracting = true;
      _loading = true;
    });
    await _ctrl.loadRequest(Uri.parse('https://www.newgrounds.com/account/'));
  }

  Future<void> _doExtract() async {
    try {
      // 1. Имя из тайтла страницы: "G2961's Account Page"
      final title =
          await _ctrl.runJavaScriptReturningResult('document.title') as String;
      final cleanTitle = title.replaceAll(RegExp(r'^"|"$'), '').trim();
      final titleMatch =
          RegExp(r"^([^']+)'s Account Page", caseSensitive: false)
              .firstMatch(cleanTitle);
      String username = titleMatch?.group(1)?.toLowerCase().trim() ?? '';

      // 2. Фоллбэк: заголовок на странице аккаунта
      if (username.isEmpty) {
        final heading = await _ctrl.runJavaScriptReturningResult(r'''
          (function() {
            var h = document.querySelector(".podhead, h2, h1");
            if (!h) return "";
            var m = h.textContent.match(/([a-zA-Z0-9_-]+)'s Account/i);
            return m ? m[1].toLowerCase() : "";
          })()
        ''') as String;
        username = heading.replaceAll(RegExp(r'^"|"$'), '').trim();
      }

      // 3. Фоллбэк 2: ссылка на свой профиль в шапке (`user.newgrounds.com`)
      if (username.isEmpty) {
        final slug = await _ctrl.runJavaScriptReturningResult(r'''
          (function() {
            var a = document.querySelector('a[href*=".newgrounds.com"][class*="user"]')
                 || document.querySelector('#userpanel a[href*=".newgrounds.com"]');
            if (!a) return "";
            var m = a.href.match(/https?:\/\/([a-z0-9-]+)\.newgrounds\.com/i);
            return m && m[1] !== "www" ? m[1].toLowerCase() : "";
          })()
        ''') as String;
        username = slug.replaceAll(RegExp(r'^"|"$'), '').trim();
      }

      // 4. Сессионные куки берём нативно — в document.cookie нет HttpOnly-токена
      String cookieString =
          await NgAuth.readNativeCookies('https://www.newgrounds.com');
      if (cookieString.isEmpty) {
        final cookieResult = await _ctrl
            .runJavaScriptReturningResult('document.cookie') as String;
        cookieString = cookieResult.replaceAll(RegExp(r'^"|"$'), '');
      }

      // В лог — только имена кук, без значений.
      final names = cookieString
          .split(';')
          .map((c) => c.split('=').first.trim())
          .where((c) => c.isNotEmpty)
          .join(',');
      debugPrint('[ng-login] title="$cleanTitle" user="$username" '
          'cookies=[$names]');

      if (!mounted) return;
      setState(() {
        _extracting = false;
        _loading = false;
      });

      // Признак входа — именно имя со страницы аккаунта: кука `newgrounds_session`
      // выдаётся и гостю, по ней отличить нельзя.
      if (username.isEmpty) {
        setState(() => _error = 'Newgrounds вернул страницу «$cleanTitle» — кажется, '
            'вход не завершён. Попробуй ещё раз.');
        return;
      }

      await _saveAndPop(username, cookieString);
    } catch (e) {
      debugPrint('[ng-login] extract failed: $e');
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _loading = false;
        _error = 'Login failed: $e';
      });
    }
  }

  Future<void> _saveAndPop(String username, String cookie) async {
    _done = true;
    await NgAuth.save(cookie: cookie, username: username);
    if (mounted) Navigator.pop(context, username);
  }

  /// Начать паспорт заново — после ошибки или по кнопке в шапке.
  void _restart() {
    setState(() {
      _error = null;
      _done = false;
      _extracting = false;
      _onPassportPage = false;
      _loading = true;
    });
    _ctrl.loadRequest(Uri.parse('https://www.newgrounds.com/passport/'));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _extracting;

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
                onBack: () => Navigator.maybePop(context), onReload: _restart),
            Expanded(
              // Под стоит на серой колонке `#main`, как любая страница 2015.
              child: NgPageColumn(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                child: NgPod.fill(
                  icon: 'user',
                  title:
                      _extracting ? 'Detecting Account' : 'Newgrounds Passport',
                  skin: _skin,
                  // «Done»-плашка доступна всегда, пока не идёт извлечение: новый
                  // паспорт логинится ажаксом и может не делать перехода, тогда
                  // автодетект не сработает и завершить надо руками.
                  action: !_extracting && _error == null
                      ? NgPlateLink(label: 'Done »', onTap: _onDone)
                      : null,
                  child: _error != null ? _errorBody() : _webBody(busy),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webBody(bool busy) {
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _ctrl)),
        // Полосатый индикатор ложится поверх страницы, чтобы вёрстка пода не
        // прыгала на каждом переходе паспорта.
        if (busy)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ColoredBox(
              color: ngBlack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NgLoading(width: 140),
                  if (_extracting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Reading your account page…', style: ngLabel),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _errorBody() {
    return SingleChildScrollView(
      child: NgNotice(
        text: _error!,
        icon: 'flag',
        action: NgButton(
          label: 'Try Again',
          icon: 'key',
          width: 122,
          onPressed: _restart,
        ),
      ),
    );
  }
}

// ── Шапка ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onReload;
  const _TopBar({required this.onBack, required this.onReload});

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
            onTap: onBack,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(NgTex.logo, height: 40, fit: BoxFit.contain),
            ),
          ),
          NgIconButton(
            icon: 'refresh',
            padding: 10,
            tooltip: 'Restart login',
            onTap: onReload,
          ),
        ],
      ),
    );
  }
}
