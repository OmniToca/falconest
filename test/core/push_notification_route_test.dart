import 'package:flutter_test/flutter_test.dart';
import 'package:falconest/core/services/push_notification_service.dart';

void main() {
  group('PushNotificationService.routeFromFcmData', () {
    test('vrací cestu z data.route (stejný kontrakt jako FCM data z Edge)', () {
      expect(
        PushNotificationService.routeFromFcmData({
          'route': '/worker/task/550e8400-e29b-41d4-a716-446655440000',
          'task_id': '550e8400-e29b-41d4-a716-446655440000',
        }),
        '/worker/task/550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('prázdné nebo chybějící route → null', () {
      expect(PushNotificationService.routeFromFcmData({}), isNull);
      expect(PushNotificationService.routeFromFcmData({'route': ''}), isNull);
      expect(PushNotificationService.routeFromFcmData({'route': '   '}), isNull);
    });
  });
}
