import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Callback při úspěšném vložení obrázku ze schránky.
typedef TaskDraftClipboardImageHandler = void Function(
  Uint8List bytes,
  String mimeType,
);

/// Handle pro zrušení listeneru (dispose dialogu).
class TaskDraftClipboardImageSubscription {
  TaskDraftClipboardImageSubscription(this._cancel);
  final void Function() _cancel;
  void cancel() => _cancel();
}

/// Web: zachytí paste event s image/* ze schránky (Cmd/Ctrl+V screenshotu).
TaskDraftClipboardImageSubscription? listenForTaskDraftClipboardImages(
  TaskDraftClipboardImageHandler onImage,
) {
  void handlePaste(web.Event event) {
    final pasteEvent = event as web.ClipboardEvent;
    final clipboard = pasteEvent.clipboardData;
    if (clipboard == null) return;

    final items = clipboard.items;
    final len = items.length;
    for (var i = 0; i < len; i++) {
      final item = items[i];
      final type = item.type;
      if (!type.startsWith('image/')) continue;

      // Zabrání vložení binárních dat do TextField.
      pasteEvent.preventDefault();

      final file = item.getAsFile();
      if (file == null) continue;

      final mime = type.isNotEmpty ? type : 'image/png';
      file.arrayBuffer().toDart.then((JSArrayBuffer buffer) {
        final bytes = buffer.toDart.asUint8List();
        if (bytes.isEmpty) return;
        onImage(bytes, mime);
      });
      break;
    }
  }

  final jsHandler = handlePaste.toJS;
  web.document.addEventListener('paste', jsHandler);

  return TaskDraftClipboardImageSubscription(() {
    web.document.removeEventListener('paste', jsHandler);
  });
}
