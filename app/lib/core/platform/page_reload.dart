/// Cross-platform page reload.
///
/// On web it reloads the browser page (the only reliable way to recover from
/// a stuck IndexedDB connection); on other platforms it is a no-op.
library;

export 'page_reload_stub.dart' if (dart.library.js_interop) 'page_reload_web.dart';
