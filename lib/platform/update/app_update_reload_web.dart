import 'dart:js_interop';

@JS('window.location.reload')
external void _reload();

bool reloadForAppUpdate() {
  _reload();
  return true;
}
