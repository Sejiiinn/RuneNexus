// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class GoogleIdentityButton extends StatefulWidget {
  const GoogleIdentityButton({
    required this.clientId,
    required this.onCredential,
    required this.onUnavailable,
    super.key,
  });

  final String clientId;
  final ValueChanged<String> onCredential;
  final VoidCallback onUnavailable;

  @override
  State<GoogleIdentityButton> createState() => _GoogleIdentityButtonState();
}

class _GoogleIdentityButtonState extends State<GoogleIdentityButton> {
  static int _nextViewId = 0;

  late final String _viewType;
  late final html.DivElement _host;
  late final JSExportedDartFunction _credentialCallback;
  bool _unavailableReported = false;

  @override
  void initState() {
    super.initState();
    _ensureGoogleIdentityScript();
    _viewType = 'rune-nexus-google-sign-in-${_nextViewId++}';
    _host = html.DivElement()
      ..style.width = '100%'
      ..style.height = '44px'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center';
    _credentialCallback = ((JSObject response) {
      final credential = response['credential'];
      if (credential != null && credential.isA<JSString>()) {
        final rawCredential = (credential as JSString).toDart;
        if (rawCredential.isNotEmpty) {
          widget.onCredential(rawCredential);
        }
      }
    }).toJS;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _host,
    );
    unawaited(_renderWhenReady());
  }

  void _ensureGoogleIdentityScript() {
    const source = 'https://accounts.google.com/gsi/client';
    if (html.document.querySelector('script[src="$source"]') != null) {
      return;
    }
    final script = html.ScriptElement()
      ..src = source
      ..async = true
      ..defer = true;
    html.document.head?.append(script);
  }

  Future<void> _renderWhenReady() async {
    for (var attempt = 0; attempt < 80 && mounted; attempt += 1) {
      final identityApi = _identityApi();
      final hostWidth = _host.clientWidth;
      if (identityApi != null && hostWidth > 0) {
        final buttonWidth = hostWidth.clamp(200, 300);
        identityApi.callMethod<JSAny?>(
          'initialize'.toJS,
          {
            'client_id': widget.clientId,
            'callback': _credentialCallback,
          }.jsify(),
        );
        identityApi.callMethod<JSAny?>(
          'renderButton'.toJS,
          _host.jsify(),
          {
            'type': 'standard',
            'theme': 'filled_black',
            'size': 'large',
            'text': 'continue_with',
            'shape': 'rectangular',
            'logo_alignment': 'left',
            'width': buttonWidth,
          }.jsify(),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _reportUnavailable();
  }

  JSObject? _identityApi() {
    final google = globalContext['google'];
    if (google == null || !google.isA<JSObject>()) {
      return null;
    }
    final accounts = (google as JSObject)['accounts'];
    if (accounts == null || !accounts.isA<JSObject>()) {
      return null;
    }
    final identity = (accounts as JSObject)['id'];
    return identity != null && identity.isA<JSObject>()
        ? identity as JSObject
        : null;
  }

  void _reportUnavailable() {
    if (_unavailableReported || !mounted) {
      return;
    }
    _unavailableReported = true;
    widget.onUnavailable();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 44, child: HtmlElementView(viewType: _viewType));
  }
}
