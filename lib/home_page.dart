import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'app_settings.dart';
import 'file_saver.dart';
import 'offline_page.dart';
import 'settings_page.dart';
import 'translate_sheet.dart';

const _bootJs = r'''
(function () {
  if (window.__waweb) return;
  window.__waweb = true;
  var blobs = {};
  var oc = URL.createObjectURL;
  var orv = URL.revokeObjectURL;

  function call() {
    try {
      var f = window.flutter_inappwebview;
      f.callHandler.apply(f, arguments);
    } catch (e) {}
  }

  URL.createObjectURL = function (o) {
    var u = oc.call(URL, o);
    try { blobs[u] = o; } catch (e) {}
    return u;
  };
  URL.revokeObjectURL = function (u) {
    setTimeout(function () { delete blobs[u]; }, 30000);
    return orv.call(URL, u);
  };

  function toFlutter(b, name) {
    var r = new FileReader();
    r.onloadend = function () { call('blob', r.result, b.type || '', name || ''); };
    r.readAsDataURL(b);
  }
  function sendUrl(u, name) {
    var b = blobs[u];
    if (b) return toFlutter(b, name);
    fetch(u).then(function (x) { return x.blob(); })
      .then(function (b) { toFlutter(b, name); })
      .catch(function (e) { call('blobError', String(e)); });
  }
  window.__wawebSend = sendUrl;

  var ac = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function () {
    try {
      if (this.hasAttribute('download') && this.href && this.href.indexOf('blob:') === 0) {
        sendUrl(this.href, this.getAttribute('download'));
        return;
      }
    } catch (e) {}
    return ac.apply(this, arguments);
  };
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[download]') : null;
    if (a && a.href && a.href.indexOf('blob:') === 0) {
      e.preventDefault();
      sendUrl(a.href, a.getAttribute('download'));
    }
  }, true);

  var last = null;
  function theme() {
    var b = document.body;
    if (!b) return;
    var d = b.classList.contains('dark');
    if (d !== last) { last = d; call('theme', d); }
  }
  var st;
  document.addEventListener('selectionchange', function () {
    clearTimeout(st);
    st = setTimeout(function () {
      var s = String(window.getSelection() || '');
      if (s.trim()) call('sel', s);
    }, 250);
  });

  function init() {
    theme();
    new MutationObserver(theme).observe(document.body, { attributes: true, attributeFilter: ['class'] });
    setInterval(function () { last = null; theme(); }, 8000);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
''';

const _wipeJs = r'''
(async function () {
  try {
    localStorage.clear();
    sessionStorage.clear();
    var d = await indexedDB.databases();
    for (var i = 0; i < d.length; i++) { indexedDB.deleteDatabase(d[i].name); }
    var k = await caches.keys();
    for (var j = 0; j < k.length; j++) { await caches.delete(k[j]); }
    var r = await navigator.serviceWorker.getRegistrations();
    for (var x = 0; x < r.length; x++) { await r[x].unregister(); }
  } catch (e) {}
})();
''';

// Viewport dinamis: lebar layout W (desktop = 980) dan skala pas layar.
// {{W}} dan {{L}} diisi dari Dart.
const _viewJs = r'''
(function () {
  var W = {{W}}, L = {{L}}, forced = false;
  function content() {
    var sw = Math.max(screen.width || 360, 200);
    var s = Math.max(0.05, Math.min(5, sw / W));
    return 'width=' + W + ', initial-scale=' + s.toFixed(4) +
      ', minimum-scale=0.05, maximum-scale=5, user-scalable=' + (L ? 'no' : 'yes');
  }
  function apply() {
    var h = document.head || document.documentElement;
    if (!h) return;
    var m = document.querySelector('meta[name=viewport]');
    if (!m) { m = document.createElement('meta'); m.name = 'viewport'; h.appendChild(m); }
    var c = forced ? 'width=' + (W + 1) : content();
    if (m.getAttribute('content') !== c) m.setAttribute('content', c);
  }
  window.__wawebView = function (w, l, force) {
    W = w; L = l;
    if (force) {
      forced = true; apply();
      setTimeout(function () { forced = false; apply(); }, 80);
    } else { apply(); }
  };
  apply();
  document.addEventListener('DOMContentLoaded', apply);
  window.addEventListener('orientationchange', function () { setTimeout(apply, 200); });
  try {
    var mo = new MutationObserver(apply);
    mo.observe(document.documentElement, { childList: true });
    var t = setInterval(function () {
      if (document.head) { mo.observe(document.head, { childList: true }); clearInterval(t); }
    }, 50);
  } catch (e) {}
})();
''';

const _escJs = r'''
(function () {
  var t = document.activeElement || document.body;
  ['keydown', 'keyup'].forEach(function (n) {
    t.dispatchEvent(new KeyboardEvent(n, { key: 'Escape', code: 'Escape', keyCode: 27, which: 27, bubbles: true }));
  });
})();
''';

class HomePage extends StatefulWidget {
  final AppSettings settings;
  const HomePage({super.key, required this.settings});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _url = 'https://web.whatsapp.com/';
  static const _ua =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  InAppWebViewController? _c;
  bool _offline = false;
  bool _failed = false;
  bool _menuOpen = false;
  final ValueNotifier<int> _progress = ValueNotifier<int>(0);
  String _sel = '';
  String _userAgent = _ua;
  bool _uaReady = false;
  double? _dragY;
  int _appliedZoom = 0;
  bool _appliedLock = true;
  bool? _appliedFs;
  DateTime _lastBack = DateTime.fromMillisecondsSinceEpoch(0);

  AppSettings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    _appliedZoom = s.zoom;
    _appliedLock = s.zoomLock;
    s.addListener(_onSettings);
    WidgetsBinding.instance.addObserver(this);
    _applyFullscreen();
    _initUa();
    _check();
  }

  @override
  void dispose() {
    s.removeListener(_onSettings);
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _initUa() async {
    try {
      final d = await InAppWebViewController.getDefaultUserAgent()
          .timeout(const Duration(seconds: 3));
      final u = d
          .replaceAll(RegExp(r'\(Linux; Android[^)]*\)'), '(X11; Linux x86_64)')
          .replaceAll(RegExp(r' Version/[\d.]+'), '')
          .replaceAll(' Mobile', '');
      if (u.contains('Chrome/')) _userAgent = u;
    } catch (_) {}
    if (mounted) setState(() => _uaReady = true);
  }

  void _applyFullscreen() {
    if (_appliedFs == s.fullscreen) return;
    _appliedFs = s.fullscreen;
    SystemChrome.setEnabledSystemUIMode(
      s.fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _onSettings() {
    if (_c != null &&
        (_appliedZoom != s.zoom || _appliedLock != s.zoomLock)) {
      _appliedZoom = s.zoom;
      _appliedLock = s.zoomLock;
      _c!.setSettings(settings: _webSettings());
      _applyView();
    }
    _applyFullscreen();
    if (mounted) setState(() {});
  }

  void _applyView({bool force = false}) {
    _c?.evaluateJavascript(
        source:
            'window.__wawebView&&window.__wawebView(${viewWidthFor(s.zoom)},${s.zoomLock},$force);');
  }

  /// Kembali ke tampilan desktop (100%) dan buang zoom cubitan.
  void _resetView() {
    if (s.zoom != 100) s.setZoom(100);
    _applyView(force: true);
    if (s.haptic) HapticFeedback.selectionClick();
  }

  InAppWebViewSettings _webSettings() => InAppWebViewSettings(
        userAgent: _userAgent,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        cacheEnabled: true,
        thirdPartyCookiesEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        supportZoom: !s.zoomLock,
        builtInZoomControls: !s.zoomLock,
        displayZoomControls: false,
        textZoom: 100,
        useOnDownloadStart: true,
        useShouldOverrideUrlLoading: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        overScrollMode: OverScrollMode.NEVER,
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
        allowFileAccess: false,
        allowContentAccess: true,
        transparentBackground: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      );

  Future<void> _check() async {
    final ok = await hasInternet();
    if (!mounted) return;
    if (_offline != !ok) setState(() => _offline = !ok);
    if (ok && _failed) {
      setState(() => _failed = false);
      _load();
    }
  }

  Future<void> _retry() async {
    final ok = await hasInternet();
    if (!mounted) return;
    setState(() => _offline = !ok);
    if (ok) {
      setState(() => _failed = false);
      _load();
    }
  }

  void _load() {
    _c?.loadUrl(urlRequest: URLRequest(url: WebUri(_url)));
  }

  bool _isWa(String h) =>
      h == 'whatsapp.com' ||
      h.endsWith('.whatsapp.com') ||
      h.endsWith('.whatsapp.net');

  void _external(WebUri u) {
    Native.launch(u.toString());
  }

  void _toast(String msg, {String? label, VoidCallback? onTap}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      action: label == null
          ? null
          : SnackBarAction(label: label, onPressed: onTap ?? () {}),
    ));
  }

  String _ext(String mime) {
    const map = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'image/gif': '.gif',
      'video/mp4': '.mp4',
      'audio/ogg': '.ogg',
      'audio/mpeg': '.mp3',
      'audio/mp4': '.m4a',
      'application/pdf': '.pdf',
      'text/plain': '.txt',
    };
    return map[mime.split(';').first.trim()] ?? '';
  }

  Future<void> _saveBlob(List<dynamic> args) async {
    try {
      final data = args[0] as String;
      var mime = (args.length > 1 ? args[1] as String? : null) ?? '';
      var name = (args.length > 2 ? args[2] as String? : null) ?? '';
      final comma = data.indexOf(',');
      final bytes = base64Decode(data.substring(comma + 1));
      if (mime.isEmpty) mime = 'application/octet-stream';
      name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (name.isEmpty) {
        name = 'waweb_${DateTime.now().millisecondsSinceEpoch}${_ext(mime)}';
      } else if (!name.contains('.')) {
        name = '$name${_ext(mime)}';
      }
      final uri = await FileSaver.save(name, mime, bytes);
      _toast(
        'Tersimpan di Download/waweb',
        label: uri == null ? null : 'Buka',
        onTap: uri == null ? null : () => FileSaver.open(uri, mime),
      );
    } catch (_) {
      _toast('Gagal menyimpan file');
    }
  }

  Future<PermissionResponse> _onPermission(
      InAppWebViewController c, PermissionRequest r) async {
    final need = <String>{};
    for (final res in r.resources) {
      if (res == PermissionResourceType.CAMERA ||
          res == PermissionResourceType.CAMERA_AND_MICROPHONE) {
        need.add('android.permission.CAMERA');
      }
      if (res == PermissionResourceType.MICROPHONE ||
          res == PermissionResourceType.CAMERA_AND_MICROPHONE) {
        need.add('android.permission.RECORD_AUDIO');
      }
    }
    final ok = need.isEmpty ? true : await Native.perms(need.toList());
    return PermissionResponse(
      resources: r.resources,
      action: ok ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY,
    );
  }

  Future<void> _openTranslate() async {
    final sel = _sel;
    _sel = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TranslateSheet(
        initial: sel,
        lang: s.lang,
        onLang: s.setLang,
      ),
    );
  }

  Future<void> _clearCache() async {
    await InAppWebViewController.clearAllCache();
  }

  Future<void> _clearData() async {
    await CookieManager.instance().deleteAllCookies();
    await _c?.evaluateJavascript(source: _wipeJs);
    await Future.delayed(const Duration(seconds: 1));
    await InAppWebViewController.clearAllCache();
    _load();
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsPage(
        settings: s,
        onClearCache: _clearCache,
        onClearData: _clearData,
      ),
    ));
  }

  void _togglePill() {
    if (s.haptic) HapticFeedback.selectionClick();
    setState(() => _menuOpen = !_menuOpen);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showOffline = _offline || _failed;
    if (!_uaReady) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_menuOpen) {
          setState(() => _menuOpen = false);
          return;
        }
        final now = DateTime.now();
        if (now.difference(_lastBack) < const Duration(milliseconds: 900)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        await _c?.evaluateJavascript(source: _escJs);
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final h = box.maxHeight;
            const pillH = 64.0;
            final y = ((_dragY ?? s.pillY) * h).clamp(0.0, h - pillH);
            return Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _progress,
                        builder: (_, p, __) => SizedBox(
                          height: 2,
                          child: p < 100
                              ? LinearProgressIndicator(
                                  value: p / 100,
                                  minHeight: 2,
                                  backgroundColor: Colors.transparent,
                                )
                              : null,
                        ),
                      ),
                      Expanded(
                        child: InAppWebView(
                          initialUrlRequest: URLRequest(url: WebUri(_url)),
                          initialSettings: _webSettings(),
                          initialUserScripts: UnmodifiableListView<UserScript>([
                            UserScript(
                              source: _viewJs
                                  .replaceFirst('{{W}}', '${viewWidthFor(s.zoom)}')
                                  .replaceFirst('{{L}}', '${s.zoomLock}'),
                              injectionTime:
                                  UserScriptInjectionTime.AT_DOCUMENT_START,
                            ),
                            UserScript(
                              source: _bootJs,
                              injectionTime:
                                  UserScriptInjectionTime.AT_DOCUMENT_START,
                            ),
                          ]),
                          onWebViewCreated: (c) {
                            _c = c;
                            c.addJavaScriptHandler(
                              handlerName: 'theme',
                              callback: (a) {
                                if (a.isNotEmpty && a.first is bool) {
                                  final d = a.first as bool;
                                  if (s.waDark != d) s.setWaDark(d);
                                }
                                return null;
                              },
                            );
                            c.addJavaScriptHandler(
                              handlerName: 'sel',
                              callback: (a) {
                                if (a.isNotEmpty && a.first is String) {
                                  _sel = a.first as String;
                                }
                                return null;
                              },
                            );
                            c.addJavaScriptHandler(
                              handlerName: 'blob',
                              callback: (a) {
                                _saveBlob(a);
                                return null;
                              },
                            );
                            c.addJavaScriptHandler(
                              handlerName: 'blobError',
                              callback: (a) {
                                _toast('Gagal mengunduh file');
                                return null;
                              },
                            );
                          },
                          onLoadStart: (c, u) {
                            if (_failed) setState(() => _failed = false);
                          },
                          onProgressChanged: (c, p) => _progress.value = p,
                          onReceivedError: (c, req, err) async {
                            if (!(req.isForMainFrame ?? false)) return;
                            final t = err.type;
                            final net = t == WebResourceErrorType.HOST_LOOKUP ||
                                t == WebResourceErrorType.TIMEOUT ||
                                t == WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                                t == WebResourceErrorType.NOT_CONNECTED_TO_INTERNET;
                            if (net || !await hasInternet()) {
                              if (mounted) setState(() => _failed = true);
                            }
                          },
                          shouldOverrideUrlLoading: (c, a) async {
                            final u = a.request.url;
                            if (u == null) return NavigationActionPolicy.ALLOW;
                            final sc = u.scheme;
                            if (sc != 'http' && sc != 'https') {
                              if (sc == 'blob' ||
                                  sc == 'data' ||
                                  sc == 'about' ||
                                  sc == 'javascript') {
                                return NavigationActionPolicy.ALLOW;
                              }
                              _external(u);
                              return NavigationActionPolicy.CANCEL;
                            }
                            if (_isWa(u.host) || !a.isForMainFrame) {
                              return NavigationActionPolicy.ALLOW;
                            }
                            _external(u);
                            return NavigationActionPolicy.CANCEL;
                          },
                          onCreateWindow: (c, a) async {
                            final u = a.request.url;
                            if (u != null) _external(u);
                            return true;
                          },
                          onDownloadStartRequest: (c, r) async {
                            _toast('Mengunduh…');
                            final name = r.suggestedFilename ?? '';
                            await c.evaluateJavascript(
                              source:
                                  'window.__wawebSend(${jsonEncode(r.url.toString())}, ${jsonEncode(name)});',
                            );
                          },
                          onPermissionRequest: _onPermission,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_menuOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = false),
                      child: const ColoredBox(color: Color(0x33000000)),
                    ),
                  ),
                if (_menuOpen)
                  Align(
                    alignment: s.pillRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: _panel(cs, h),
                    ),
                  ),
                if (!showOffline)
                  Positioned(
                    top: y,
                    right: s.pillRight ? 0 : null,
                    left: s.pillRight ? null : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _togglePill,
                      onVerticalDragUpdate: (d) => setState(() {
                        final ny = ((_dragY ?? s.pillY) * h + d.delta.dy) / h;
                        _dragY = ny.clamp(0.0, (h - pillH) / h);
                      }),
                      onVerticalDragEnd: (_) {
                        final v = _dragY;
                        _dragY = null;
                        if (v != null) s.setPillY(v);
                      },
                      child: SizedBox(
                        width: 28,
                        height: pillH,
                        child: Align(
                          alignment: s.pillRight
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 6,
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showOffline)
                  Positioned.fill(child: OfflinePage(onRetry: _retry)),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _panel(ColorScheme cs, double h) {
    Widget item(IconData icon, String label, VoidCallback f) => ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          minLeadingWidth: 24,
          horizontalTitleGap: 12,
          leading: Icon(icon, size: 22),
          title: Text(label),
          onTap: () {
            setState(() => _menuOpen = false);
            f();
          },
        );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(
          scale: 0.94 + 0.06 * v,
          alignment:
              s.pillRight ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      ),
      child: Material(
        color: cs.surfaceContainerHigh,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: SizedBox(
          width: 240,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h - 32),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                item(Icons.refresh_rounded, 'Muat ulang', () => _c?.reload()),
                item(Icons.translate_rounded, 'Terjemahkan', _openTranslate),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Kecilkan web',
                        icon: const Icon(Icons.zoom_out_rounded, size: 24),
                        onPressed: () => s.zoomOut(),
                      ),
                      Expanded(
                        child: Center(child: Text('Web ${s.zoom}%')),
                      ),
                      IconButton(
                        tooltip: 'Besarkan web',
                        icon: const Icon(Icons.zoom_in_rounded, size: 24),
                        onPressed: () => s.zoomIn(),
                      ),
                    ],
                  ),
                ),
                item(Icons.desktop_windows_rounded, 'Reset ke tampilan desktop',
                    _resetView),
                item(
                  s.zoomLock ? Icons.lock_rounded : Icons.lock_open_rounded,
                  s.zoomLock ? 'Zoom jari: terkunci' : 'Zoom jari: terbuka',
                  () {
                    s.setZoomLock(!s.zoomLock);
                    _toast(s.zoomLock
                        ? 'Zoom dikunci'
                        : 'Cubit layar untuk zoom in / out');
                  },
                ),
                item(
                  s.fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  s.fullscreen ? 'Keluar layar penuh' : 'Layar penuh',
                  () => s.setFullscreen(!s.fullscreen),
                ),
                item(Icons.download_rounded, 'Unduhan', FileSaver.openDownloads),
                item(Icons.cleaning_services_rounded, 'Hapus cache', () async {
                  await _clearCache();
                  _toast('Cache dihapus');
                }),
                item(Icons.settings_rounded, 'Pengaturan', _openSettings),
                item(Icons.info_outline_rounded, 'Tentang',
                    () => showAbout(context)),
                item(Icons.close_rounded, 'Tutup aplikasi',
                    () => SystemNavigator.pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
