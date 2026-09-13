import 'package:flutter_test/flutter_test.dart';
import 'package:falconest/features/admin/providers/admin_task_status_timestamps.dart';

void main() {
  group('applyAdminTaskStatusTimestampsToUpdate', () {
    test('in_progress nastaví started_at když chybí', () {
      final fields = <String, dynamic>{'status': 'in_progress'};
      applyAdminTaskStatusTimestampsToUpdate(
        fields,
        previousStatus: 'assigned',
        currentStartedAt: null,
      );
      expect(fields['started_at'], isA<String>());
      expect(fields.containsKey('completed_at'), isFalse);
    });

    test('in_progress nemění existující started_at', () {
      final fields = <String, dynamic>{'status': 'in_progress'};
      final existing = DateTime.utc(2026, 1, 1);
      applyAdminTaskStatusTimestampsToUpdate(
        fields,
        previousStatus: 'assigned',
        currentStartedAt: existing,
      );
      expect(fields.containsKey('started_at'), isFalse);
    });

    test('completed nastaví completed_at i started_at fallback', () {
      final fields = <String, dynamic>{'status': 'completed'};
      applyAdminTaskStatusTimestampsToUpdate(
        fields,
        previousStatus: 'assigned',
        currentStartedAt: null,
        currentCompletedAt: null,
      );
      expect(fields['completed_at'], isA<String>());
      expect(fields['started_at'], fields['completed_at']);
    });

    test('assigned vynuluje razítka', () {
      final fields = <String, dynamic>{'status': 'assigned'};
      applyAdminTaskStatusTimestampsToUpdate(
        fields,
        previousStatus: 'in_progress',
        currentStartedAt: DateTime.utc(2026, 1, 1),
        currentCompletedAt: null,
      );
      expect(fields['started_at'], isNull);
      expect(fields['completed_at'], isNull);
    });

    test('stejný status nemění razítka', () {
      final fields = <String, dynamic>{'status': 'in_progress'};
      applyAdminTaskStatusTimestampsToUpdate(
        fields,
        previousStatus: 'in_progress',
        currentStartedAt: DateTime.utc(2026, 1, 1),
      );
      expect(fields.containsKey('started_at'), isFalse);
    });
  });
}
