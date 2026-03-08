/// Web implementace – šablony se načítají pouze online (Supabase). Worker na webu vrací [].
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/models/message_template_local.dart';

final messageTemplatesForWorkerProvider =
    FutureProvider.family<List<MessageTemplateLocal>, String>((ref, tenantId) async {
  return [];
});
