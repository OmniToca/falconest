import 'package:flutter_test/flutter_test.dart';
import 'package:falconest/core/offline/smart_merge_rules.dart';
import 'package:falconest/core/repositories/task/task_insert_sanitizer.dart';

void main() {
  group('hasTimestampMergeConflict', () {
    test('bez server razítka není konflikt', () {
      expect(
        hasTimestampMergeConflict(
          serverUpdatedAt: null,
          lastSyncedAt: DateTime.utc(2026, 1, 1),
        ),
        isFalse,
      );
    });

    test('chybějící lastSyncedAt = konflikt', () {
      expect(
        hasTimestampMergeConflict(
          serverUpdatedAt: DateTime.utc(2026, 1, 2),
          lastSyncedAt: null,
        ),
        isTrue,
      );
    });

    test('server novější než lastSyncedAt = konflikt', () {
      expect(
        hasTimestampMergeConflict(
          serverUpdatedAt: DateTime.utc(2026, 1, 3),
          lastSyncedAt: DateTime.utc(2026, 1, 2),
        ),
        isTrue,
      );
    });

    test('server starší nebo stejný = bez konfliktu', () {
      final t = DateTime.utc(2026, 1, 2);
      expect(
        hasTimestampMergeConflict(serverUpdatedAt: t, lastSyncedAt: t),
        isFalse,
      );
      expect(
        hasTimestampMergeConflict(
          serverUpdatedAt: DateTime.utc(2026, 1, 1),
          lastSyncedAt: t,
        ),
        isFalse,
      );
    });
  });

  group('mergeConflictNotes', () {
    test('jen lokál / jen server', () {
      expect(mergeConflictNotes(serverNotes: null, localNotes: 'A'), 'A');
      expect(mergeConflictNotes(serverNotes: 'B', localNotes: ''), 'B');
    });

    test('oba texty se spojí s prefixy', () {
      expect(
        mergeConflictNotes(serverNotes: 'admin', localNotes: 'worker'),
        '[Admin]: admin\n[Worker]: worker',
      );
    });

    test('shodné texty se neduplikují', () {
      expect(
        mergeConflictNotes(serverNotes: 'same', localNotes: 'same'),
        'same',
      );
    });
  });

  group('applyTaskSmartMerge', () {
    test('status má přednost lokální (worker)', () {
      final r = applyTaskSmartMerge(
        localStatus: 'completed',
        localDescription: 'hotovo v terénu',
        localMetadata: {'photo': true},
        serverDescription: 'poznámka admina',
        serverMetadata: {'price': 100},
        serverTitle: 'Úklid',
        serverTaskType: 'cleaning',
        serverScheduledStart: DateTime.utc(2026, 5, 1, 10),
      );
      expect(r.status, 'completed');
      expect(r.description, contains('[Admin]:'));
      expect(r.description, contains('[Worker]:'));
      expect(r.metadata['price'], 100);
      expect(r.metadata['photo'], true);
      expect(r.title, 'Úklid');
      expect(r.taskType, 'cleaning');
    });
  });

  group('sanitizeTaskInsertPayload', () {
    test('doplní due_date z estimated_minutes', () {
      final start = DateTime.utc(2026, 6, 1, 8);
      final out = sanitizeTaskInsertPayload({
        'scheduled_start': start.toIso8601String(),
        'description': 'test',
        'metadata': {'estimated_minutes': 45},
        'title_i18n': null,
      });
      expect(out['title_i18n'], isA<Map>());
      final due = DateTime.parse(out['due_date'] as String);
      expect(due.difference(start).inMinutes, 45);
    });

    test('nulová délka → výchozí 60 min', () {
      final start = DateTime.utc(2026, 6, 1, 8);
      final out = sanitizeTaskInsertPayload({
        'scheduled_start': start.toIso8601String(),
        'due_date': start.toIso8601String(),
        'metadata': <String, dynamic>{},
      });
      final due = DateTime.parse(out['due_date'] as String);
      expect(due.difference(start).inMinutes, kDefaultTaskDurationMinutes);
    });
  });

  group('DriftMutationQueueService retry klasifikace (pure)', () {
    test('síťové chybové texty jsou retryable heuristikou', () {
      // PROČ: Isolujeme rozpoznání bez importu Drift – stejná logika jako isNetworkError.
      bool looksNetwork(Object e) {
        final msg = e.toString().toLowerCase();
        return msg.contains('socket') ||
            msg.contains('connection') ||
            msg.contains('network') ||
            msg.contains('timeout');
      }

      expect(looksNetwork(Exception('SocketException: failed')), isTrue);
      expect(looksNetwork(Exception('timeout waiting')), isTrue);
      expect(looksNetwork(Exception('permission denied')), isFalse);
    });
  });
}
