/// Naslouchání Ctrl/Cmd+V s obrázkem ze schránky (web vs. stub).
///
/// Web: `paste` event na document. IO: no-op (dispečer použije file picker).
library;

export 'task_draft_clipboard_image_stub.dart'
    if (dart.library.html) 'task_draft_clipboard_image_web.dart';
