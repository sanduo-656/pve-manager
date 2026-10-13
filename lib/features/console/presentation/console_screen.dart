import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../data/console_cookie_bridge.dart';
import '../domain/console_security.dart';

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({
    required this.title,
    required this.origin,
    required this.ticket,
    required this.consoleType,
    required this.node,
    required this.vmid,
    this.pinnedSha256,
    super.key,
  });

  final String title;
  final String origin;
  final String ticket;
  final String consoleType;
  final String node;
  final int vmid;
  final String? pinnedSha256;

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  WebViewController? _controller;
  Uri? _origin;
  String? _normalizedPin;
  String? _errorMessage;
  int _progress = 0;
  bool _isLandscape = false;
  bool _isImmersive = true;
  bool _isLeaving = false;
  bool _cookieWasSet = false;
  bool _isInitializing = false;
  bool _isDisposed = false;
  bool _pinCheckInFlight = false;
  bool _isReloading = false;
  bool _orientationChangeInFlight = false;
  bool _immersiveChangeInFlight = false;
  int _controllerGeneration = 0;
  Future<void>? _cookieClearInFlight;
  Timer? _pinMonitor;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_isInitializing || _isDisposed || _isLeaving) return;
    _isInitializing = true;
    final generation = ++_controllerGeneration;
    try {
      final Uri origin = parseConsoleOrigin(widget.origin);
      final Uri consoleUri = buildConsoleUri(
        origin: widget.origin,
        consoleType: widget.consoleType,
        node: widget.node,
        vmid: widget.vmid,
      );
      final String? normalizedPin = normalizeSha256Pin(widget.pinnedSha256);
      if (widget.ticket.isEmpty) {
        throw const FormatException('PVE ticket is required.');
      }

      _origin = origin;
      _normalizedPin = normalizedPin;
      await verifyPinnedConsoleCertificate(
        origin: origin,
        pinnedSha256: normalizedPin,
      );
      if (!_isCurrentGeneration(generation)) return;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (!_isCurrentGeneration(generation)) return;
      await _cookieClearInFlight;
      if (!_isCurrentGeneration(generation)) return;
      await ConsoleCookieBridge.setSecureCookie(
        origin: origin,
        ticket: widget.ticket,
      );
      _cookieWasSet = true;
      if (_isDisposed || _isLeaving || !mounted) {
        await _clearAuthCookie();
        return;
      }

      final WebViewController controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (!_isCurrentGeneration(generation)) {
              return NavigationDecision.prevent;
            }
            final Uri? target = Uri.tryParse(request.url);
            if (target != null && hasSameHttpsOrigin(target, origin)) {
              return NavigationDecision.navigate;
            }
            _setError('已阻止跳转到 PVE 连接以外的地址。');
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (_isCurrentGeneration(generation)) {
              setState(() {
                _progress = 0;
                _errorMessage = null;
              });
            }
          },
          onProgress: (int progress) {
            if (_isCurrentGeneration(generation)) {
              setState(() => _progress = progress);
            }
          },
          onPageFinished: (_) {
            if (_isCurrentGeneration(generation)) {
              setState(() => _progress = 100);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (_isCurrentGeneration(generation) &&
                error.isForMainFrame == true) {
              _setError('控制台加载失败：${error.description}');
            }
          },
          onSslAuthError: (SslAuthError error) {
            unawaited(_handleSslAuthError(error, origin, generation));
          },
        ),
      );

      final platformController = controller.platform;
      if (platformController is! AndroidWebViewController) {
        throw UnsupportedError('PVE 控制台目前仅支持 Android。');
      }
      await AndroidWebViewController.enableDebugging(kDebugMode);
      await platformController.setAllowFileAccess(false);
      await platformController.setAllowContentAccess(false);
      await platformController.setGeolocationEnabled(false);
      await platformController.setMixedContentMode(MixedContentMode.neverAllow);
      await platformController.setOnShowFileSelector(
        (_) async => const <String>[],
      );

      if (!_isCurrentGeneration(generation)) {
        return;
      }
      setState(() {
        _controller = controller;
        _errorMessage = null;
      });
      await controller.loadRequest(consoleUri);
      if (_isCurrentGeneration(generation)) _startPinMonitor();
    } on Object catch (error) {
      if (_isCurrentGeneration(generation)) {
        await _clearAuthCookie();
        if (_isCurrentGeneration(generation)) {
          await _blockFailedController(_friendlyInitializationError(error));
        }
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _handleSslAuthError(
    SslAuthError error,
    Uri allowedOrigin,
    int generation,
  ) async {
    try {
      await _resolveSslAuthError(error, allowedOrigin, generation);
    } on Object {
      if (!_isCurrentGeneration(generation)) return;
      await _clearAuthCookie();
      await _blockFailedController('无法安全处理控制台证书错误，连接已阻止。');
    }
  }

  Future<void> _resolveSslAuthError(
    SslAuthError error,
    Uri allowedOrigin,
    int generation,
  ) async {
    if (!_isCurrentGeneration(generation)) {
      await error.cancel();
      return;
    }
    final platformError = error.platform;
    final Uri? failingUri = platformError is AndroidSslAuthError
        ? Uri.tryParse(platformError.url)
        : null;
    final bool isExpectedOrigin =
        failingUri != null && hasSameHttpsOrigin(failingUri, allowedOrigin);
    final bool pinMatches = certificateMatchesPin(
      error.certificate?.data,
      _normalizedPin,
    );

    if (isExpectedOrigin && pinMatches) {
      await error.proceed();
      return;
    }

    await error.cancel();
    if (!_isCurrentGeneration(generation)) return;
    await _clearAuthCookie();
    if (!_isCurrentGeneration(generation)) return;
    final String detail;
    if (!isExpectedOrigin) {
      detail = '证书错误来自非当前 PVE 地址，连接已阻止。';
    } else if (_normalizedPin == null) {
      detail = '证书不受系统信任，且该连接没有已确认的证书指纹。';
    } else if (error.certificate?.data == null) {
      detail = '当前 Android 版本无法读取服务器证书，无法安全校验固定指纹。';
    } else {
      final String actual = derSha256Fingerprint(error.certificate!.data!);
      detail = '服务器证书指纹已变化，连接已阻止。\n收到：$actual';
    }
    await _blockFailedController(detail);
  }

  String _friendlyInitializationError(Object error) {
    return switch (error) {
      FormatException(:final String message) => message,
      PlatformException(:final String? message) =>
        message ?? '无法配置 Android WebView。',
      UnsupportedError(:final String message) => message,
      ConsoleCertificatePinException(:final String? actualFingerprint) =>
        actualFingerprint == null
            ? '无法安全验证控制台证书，连接已阻止。'
            : '控制台证书指纹与已固定值不一致。\n收到：$actualFingerprint',
      _ => '无法打开控制台，请重新登录后再试。',
    };
  }

  void _setError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  Future<void> _reload() async {
    if (_isReloading || _isInitializing || _isDisposed || _isLeaving) return;
    _isReloading = true;
    final controller = _controller;
    final mustInitialize =
        controller == null || _errorMessage != null || !_cookieWasSet;
    try {
      if (mustInitialize) {
        // Retire callbacks before cleaning up the failed WebView. In particular,
        // its late SSL callback must not clear the new session's cookie.
        _controllerGeneration++;
        _pinMonitor?.cancel();
        setState(() {
          _controller = null;
          _errorMessage = null;
          _progress = 0;
        });
        try {
          await controller?.loadHtmlString('<!doctype html><html></html>');
        } on Object {
          // A failed old WebView must not prevent a fresh initialization.
        }
        await _clearAuthCookie();
        await _initialize();
        return;
      }
      final generation = _controllerGeneration;
      if (!await _verifyPinOrBlock() || !_isCurrentGeneration(generation)) {
        return;
      }
      setState(() {
        _errorMessage = null;
        _progress = 0;
      });
      await controller.reload();
    } on Object catch (error) {
      if (!_isDisposed && !_isLeaving && mounted) {
        await _clearAuthCookie();
        await _blockFailedController(_friendlyInitializationError(error));
      }
    } finally {
      _isReloading = false;
    }
  }

  bool _isCurrentGeneration(int generation) =>
      mounted &&
      !_isDisposed &&
      !_isLeaving &&
      generation == _controllerGeneration;

  Future<void> _blockFailedController(String message) async {
    if (_isDisposed || _isLeaving || !mounted) return;
    final controller = _controller;
    _controllerGeneration++;
    _pinMonitor?.cancel();
    setState(() {
      _controller = null;
      _errorMessage = message;
      _progress = 100;
    });
    try {
      await controller?.loadHtmlString('<!doctype html><html></html>');
    } on Object {
      // The old WebView is already detached; the blocking error stays visible.
    }
  }

  void _startPinMonitor() {
    _pinMonitor?.cancel();
    if (_normalizedPin == null) return;
    _pinMonitor = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_verifyPinOrBlock());
    });
  }

  Future<bool> _verifyPinOrBlock() async {
    if (_pinCheckInFlight) return false;
    if (_isDisposed ||
        _isLeaving ||
        _normalizedPin == null ||
        _origin == null) {
      return !_isDisposed && !_isLeaving;
    }
    _pinCheckInFlight = true;
    final generation = _controllerGeneration;
    try {
      await verifyPinnedConsoleCertificate(
        origin: _origin!,
        pinnedSha256: _normalizedPin,
      );
      return _isCurrentGeneration(generation);
    } on ConsoleCertificatePinException catch (error) {
      if (!_isCurrentGeneration(generation)) return false;
      _pinMonitor?.cancel();
      await _clearAuthCookie();
      if (!_isCurrentGeneration(generation)) return false;
      await _blockFailedController(_friendlyInitializationError(error));
      return false;
    } finally {
      _pinCheckInFlight = false;
    }
  }

  Future<void> _toggleOrientation() async {
    if (_orientationChangeInFlight || _isDisposed || _isLeaving) return;
    _orientationChangeInFlight = true;
    final bool landscape = !_isLandscape;
    try {
      await SystemChrome.setPreferredOrientations(
        landscape
            ? <DeviceOrientation>[
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : <DeviceOrientation>[DeviceOrientation.portraitUp],
      );
      if (mounted && !_isDisposed && !_isLeaving) {
        setState(() => _isLandscape = landscape);
      }
    } on Object {
      _showPlatformError('无法切换屏幕方向，请重试。');
    } finally {
      _orientationChangeInFlight = false;
    }
  }

  Future<void> _toggleImmersiveMode() async {
    if (_immersiveChangeInFlight || _isDisposed || _isLeaving) return;
    _immersiveChangeInFlight = true;
    final bool immersive = !_isImmersive;
    try {
      await SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
      if (mounted && !_isDisposed && !_isLeaving) {
        setState(() => _isImmersive = immersive);
      }
    } on Object {
      _showPlatformError('无法切换沉浸模式，请重试。');
    } finally {
      _immersiveChangeInFlight = false;
    }
  }

  void _showPlatformError(String message) {
    if (!mounted || _isDisposed || _isLeaving) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _leave() async {
    if (_isLeaving) {
      return;
    }
    _isLeaving = true;
    await _cleanupPlatformState();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cleanupPlatformState() async {
    _pinMonitor?.cancel();
    await _clearAuthCookie();
    // A native display error must not trap the user on the console page.
    try {
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    } on Object {
      // Continue restoring the remaining platform state and leaving the page.
    }
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } on Object {
      // The page can still close when Android rejects a display-mode change.
    }
  }

  Future<void> _clearAuthCookie() async {
    final clearing = _cookieClearInFlight;
    if (clearing != null) return clearing;
    final Uri? origin = _origin;
    if (!_cookieWasSet || origin == null) return;
    _cookieWasSet = false;
    final future = _clearCookieForOrigin(origin);
    _cookieClearInFlight = future;
    try {
      await future;
    } finally {
      _cookieClearInFlight = null;
    }
  }

  Future<void> _clearCookieForOrigin(Uri origin) async {
    try {
      await ConsoleCookieBridge.clearAuthCookie(origin: origin);
    } on Object {
      // The in-memory PVE session remains owned by the app session manager.
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pinMonitor?.cancel();
    unawaited(_cleanupPlatformState());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WebViewController? controller = _controller;
    final String? error = _errorMessage;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (!didPop) {
          unawaited(_leave());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          leading: IconButton(
            tooltip: '返回',
            onPressed: _leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: <Widget>[
            IconButton(
              tooltip: '刷新控制台',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: _isLandscape ? '切换为竖屏' : '切换为横屏',
              onPressed: _toggleOrientation,
              icon: Icon(
                _isLandscape
                    ? Icons.stay_current_portrait
                    : Icons.stay_current_landscape,
              ),
            ),
            IconButton(
              tooltip: _isImmersive ? '退出沉浸模式' : '进入沉浸模式',
              onPressed: _toggleImmersiveMode,
              icon: Icon(
                _isImmersive ? Icons.fullscreen_exit : Icons.fullscreen,
              ),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (controller != null)
              WebViewWidget(
                key: ValueKey(_controllerGeneration),
                controller: controller,
              ),
            if (controller == null && error == null)
              const Center(child: CircularProgressIndicator()),
            if (error != null)
              ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.gpp_bad_outlined,
                            size: 44,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_progress < 100)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
