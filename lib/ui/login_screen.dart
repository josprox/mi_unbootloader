import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'dart:io';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Mobile Controller (InAppWebView)
  InAppWebViewController? _webViewController;

  // Desktop Controller
  dynamic _desktopWebview;
  Timer? _desktopTimer;

  bool _isDesktop = false;

  @override
  void initState() {
    super.initState();
    _isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (_isDesktop) {
      _initDesktopWebview();
    }
  }

  // --- Desktop Logic ---
  Future<void> _initDesktopWebview() async {
    try {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Xiaomi Login',
          titleBarTopPadding: Platform.isMacOS ? 20 : 0,
        ),
      );
      _desktopWebview = webview;

      webview.launch(
        'https://account.xiaomi.com/fe/service/login/password?_locale=en_IN&checkSafePhone=false&sid=18n_bbs_global&qs=%253Fcallback%253Dhttps%25253A%25252F%25252Fsgp-api.buy.mi.com%25252Fbbs%25252Fapi%25252Fglobal%25252Fuser%25252Flogin-back%25253Ffollowup%25253Dhttps%2525253A%2525252F%2525252Fc.mi.com%2525252Fglobal%252526sign%25253DODJmZGNhNzk1MGVlZGQ4YWMwODk5NWU1MTEyN2VmNmFkMDdhZWQ3Yw%25252C%25252C%2526sid%253D18n_bbs_global%2526_locale%253Den_IN%2526checkSafePhone%253Dfalse&callback=https%3A%2F%2Fsgp-api.buy.mi.com%2Fbbs%2Fapi%2Fglobal%2Fuser%2Flogin-back%3Ffollowup%3Dhttps%253A%252F%252Fc.mi.com%252Fglobal%26sign%3DODJmZGNhNzk1MGVlZGQ4YWMwODk5NWU1MTEyN2VmNmFkMDdhZWQ3Yw%2C%2C&_sign=WNmSBGAcFNN0iwkk%2BqKJ6lIE65I%3D&serviceParam=%7B%22checkSafePhone%22%3Afalse%2C%22checkSafeAddress%22%3Afalse%2C%22lsrp_score%22%3A0.0%7D&showActiveX=false&theme=&needTheme=false&bizDeviceType=',
      );

      webview.addOnUrlRequestCallback((url) {
        debugPrint('Desktop URL: $url');
      });

      webview.onClose.whenComplete(() {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      debugPrint('Error launching desktop webview: $e');
    }
  }

  // --- Mobile Logic (Refactored to InAppWebView) ---

  @override
  void dispose() {
    _desktopTimer?.cancel();
    if (_desktopWebview != null) {
      try {
        _desktopWebview.close();
      } catch (e) {
        // ignore
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Xiaomi Login')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            'https://account.xiaomi.com/fe/service/login/password?_locale=en_IN&checkSafePhone=false&sid=18n_bbs_global&qs=%253Fcallback%253Dhttps%25253A%25252F%25252Fsgp-api.buy.mi.com%25252Fbbs%25252Fapi%25252Fglobal%25252Fuser%25252Flogin-back%25253Ffollowup%25253Dhttps%2525253A%2525252F%2525252Fc.mi.com%2525252Fglobal%252526sign%25253DODJmZGNhNzk1MGVlZGQ4YWMwODk5NWU1MTEyN2VmNmFkMDdhZWQ3Yw%25252C%25252C%2526sid%253D18n_bbs_global%2526_locale%253Den_IN%2526checkSafePhone%253Dfalse&callback=https%3A%2F%2Fsgp-api.buy.mi.com%2Fbbs%2Fapi%2Fglobal%2Fuser%2Flogin-back%3Ffollowup%3Dhttps%253A%252F%252Fc.mi.com%252Fglobal%26sign%3DODJmZGNhNzk1MGVlZGQ4YWMwODk5NWU1MTEyN2VmNmFkMDdhZWQ3Yw%2C%2C&_sign=WNmSBGAcFNN0iwkk%2BqKJ6lIE65I%3D&serviceParam=%7B%22checkSafePhone%22%3Afalse%2C%22checkSafeAddress%22%3Afalse%2C%22lsrp_score%22%3A0.0%7D&showActiveX=false&theme=&needTheme=false&bizDeviceType=',
          ),
        ),
        initialSettings: InAppWebViewSettings(
          userAgent:
              "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
          useShouldOverrideUrlLoading: true,
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        onLoadStop: (controller, url) async {
          if (url != null) {
            _checkMobileCookies(url);
          }
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }

  Future<void> _checkMobileCookies(WebUri url) async {
    final urlString = url.toString();
    debugPrint('Checking cookies for: $urlString');

    CookieManager cookieManager = CookieManager.instance();

    // Define critical domains to check explicitly
    // Including broad domain matches
    final domainsToCheck = [
      url,
      WebUri('https://account.xiaomi.com'),
      WebUri('https://c.mi.com'),
      WebUri('https://xiaomi.com'),
      WebUri('https://mi.com'),
      WebUri('https://sgp-api.buy.mi.com'),
    ];

    final Map<String, String> aggregateCookies = {};

    for (final domain in domainsToCheck) {
      try {
        List<Cookie> cookies = await cookieManager.getCookies(url: domain);
        if (cookies.isNotEmpty) {
          debugPrint('--- Cookies for $domain ---');
          for (var c in cookies) {
            debugPrint('  [${c.name}] = ${c.value}');
            aggregateCookies[c.name] = c.value;
          }
        }
      } catch (e) {
        debugPrint('Error getting cookies for $domain: $e');
      }
    }

    _processCookieMap(aggregateCookies);
  }

  void _processCookieMap(Map<String, String> cookieMap) {
    // Check for serviceToken OR popRunToken to decide if we have enough info
    // Ideally we want serviceToken, but popRunToken is requested by user too
    if (cookieMap.containsKey('serviceToken')) {
      debugPrint('!!! SERVICE TOKEN FOUND !!!: ${cookieMap['serviceToken']}');

      if (mounted) {
        Navigator.of(context).pop({
          'token': cookieMap['serviceToken'],
          'popRunToken': cookieMap['popRunToken'] ?? '',
          // also grab new_bbs_serviceToken if useful
          'new_bbs_serviceToken': cookieMap['new_bbs_serviceToken'] ?? '',
          'userId': cookieMap['userId'] ?? '',
          'cUserId': cookieMap['cUserId'] ?? '',
        });
      }
    } else {
      debugPrint('serviceToken NOT found in: ${cookieMap.keys.toList()}');
    }
  }
}
