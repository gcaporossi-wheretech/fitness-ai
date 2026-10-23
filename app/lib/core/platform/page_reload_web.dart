import 'dart:js_interop';

@JS('window.location.reload')
external void _reload();

const bool canReloadPage = true;

void reloadPage() => _reload();
