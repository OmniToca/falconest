import 'dart:typed_data';

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

/// IO / desktop stub – Ctrl+V s obrázkem nepodporujeme (použij výběr souboru).
TaskDraftClipboardImageSubscription? listenForTaskDraftClipboardImages(
  TaskDraftClipboardImageHandler onImage,
) {
  return null;
}
