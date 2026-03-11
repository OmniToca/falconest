/// Podmíněný export task_detail_provider – web vs. mobil.
///
/// Na webu se nekompiluje Isar – provider vrací null, updateTaskStatus/saveTaskPhotoPath
/// jsou no-op. Na mobilu čte z Isar a mapuje na TaskDetailData DTO.
library;
export 'task_detail_provider_stub.dart'
    if (dart.library.html) 'task_detail_provider_web.dart'
    if (dart.library.io) 'task_detail_provider_mobile.dart';
