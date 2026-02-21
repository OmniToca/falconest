import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';

/// Model detailu úkolu pro Worker Task Detail Screen.
///
/// Obsahuje údaje z tasks + apartments (name, address, keybox, owner_notes).
class WorkerTaskDetail {
  const WorkerTaskDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    required this.status,
    required this.apartmentId,
    this.apartmentName,
    this.apartmentAddress,
    this.keybox,
    this.ownerNotes,
    this.photoUrl,
  });

  final String id;
  final String title;
  final String description;
  final String taskType;
  final DateTime scheduledStart;
  final String status;
  final String apartmentId;
  final String? apartmentName;
  final String? apartmentAddress;
  final String? keybox;
  final String? ownerNotes;
  final String? photoUrl;

  /// Zda je úkol v čekacím stavu (pending/assigned/draft/Nový) – lze zahájit.
  /// Stav "Nový" z DB musí zobrazit tlačítko Zahájit, ne Dokončit.
  bool get canStart {
    final s = status.trim().toLowerCase();
    return s == 'pending' || s == 'assigned' || s == 'draft' || s == 'nový' || s == 'new';
  }

  /// Zda je úkol v průběhu – zobrazí se POUZE tlačítko Dokončit.
  bool get isInProgress {
    final s = status.trim().toLowerCase();
    return s == 'in_progress' || s == 'probíhá';
  }

  /// Zda je úkol již dokončen – zobrazí se stav Hotovo a po Dokončit se obrazovka zavře.
  bool get isCompleted {
    final s = status.trim().toLowerCase();
    return s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';
  }
}

/// Načte detail úkolu podle UUID včetně apartmánu (keybox, owner_notes).
final workerTaskDetailProvider =
    FutureProvider.family<WorkerTaskDetail?, String>((ref, taskId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || taskId.isEmpty) return null;

  try {
    final res = await SupabaseService.client
        .from('tasks')
        .select(
            'id, title, description, task_type, scheduled_start, status, apartment_id, photo_url, apartments(name, address, keybox, owner_notes)')
        .eq('tenant_id', tenantId)
        .eq('id', taskId)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (res == null) return null;
    return _parseTaskDetail(res);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('WorkerTaskDetail: FETCH ERROR: $e');
    }
    return null;
  }
});

WorkerTaskDetail? _parseTaskDetail(dynamic res) {
  try {
    final map = res is Map ? Map<String, dynamic>.from(res) : null;
    if (map == null) return null;

    final raw = map['scheduled_start'];
    final start = raw is DateTime
        ? raw.toLocal()
        : (raw is String ? DateTime.tryParse(raw)?.toLocal() : null);
    if (start == null) return null;

    final idStr = (map['id']?.toString() ?? '').trim();
    if (idStr.isEmpty) return null;

    String? aptName;
    String? aptAddress;
    String? keybox;
    String? ownerNotes;
    final apartment = map['apartments'];
    if (apartment != null) {
      final a = apartment is Map
          ? apartment
          : (apartment is List && apartment.isNotEmpty ? apartment[0] : null);
      if (a != null && a is Map) {
        aptName = (a['name']?.toString() ?? '').trim();
        aptAddress = (a['address']?.toString() ?? '').trim();
        keybox = (a['keybox']?.toString() ?? '').trim();
        ownerNotes = (a['owner_notes']?.toString() ?? '').trim();
      }
    }
    if (aptName?.isEmpty ?? true) aptName = null;
    if (aptAddress?.isEmpty ?? true) aptAddress = null;
    if (keybox?.isEmpty ?? true) keybox = null;
    if (ownerNotes?.isEmpty ?? true) ownerNotes = null;

    return WorkerTaskDetail(
      id: idStr,
      title: (map['title']?.toString() ?? '').trim(),
      description: (map['description']?.toString() ?? '').trim(),
      taskType: (map['task_type']?.toString() ?? 'other').trim(),
      scheduledStart: start,
      status: (map['status']?.toString() ?? 'pending').trim(),
      apartmentId: (map['apartment_id']?.toString() ?? '').trim(),
      apartmentName: aptName,
      apartmentAddress: aptAddress,
      keybox: keybox,
      ownerNotes: ownerNotes,
      photoUrl: (map['photo_url']?.toString() ?? '').trim().isNotEmpty
          ? map['photo_url']?.toString()
          : null,
    );
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('WorkerTaskDetail: PARSE ERROR: $e');
    }
    return null;
  }
}

/// Provider pro aktualizaci stavu úkolu (zahájit/dokončit).
///
/// Po úspěchu invaliduje workerTaskDetailProvider a workerTasksProvider.
class WorkerTaskStatusNotifier extends StateNotifier<AsyncValue<void>> {
  WorkerTaskStatusNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> updateStatus(String taskId, String status) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.client.from('tasks').update({'status': status}).eq('id', taskId);
      _ref.invalidate(workerTaskDetailProvider(taskId));
      _ref.invalidate(workerTasksProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final workerTaskStatusNotifierProvider =
    StateNotifierProvider<WorkerTaskStatusNotifier, AsyncValue<void>>((ref) {
  return WorkerTaskStatusNotifier(ref);
});
