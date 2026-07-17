import 'package:flutter_test/flutter_test.dart';
import 'package:who_eats_app/src/features/dashboard/presentation/pages/app_shell_page.dart';

void main() {
  test('notification badge count reflects unread notifications', () {
    expect(
      calculateNotificationBadgeCount(unreadNotificationCount: 3),
      3,
    );
    expect(
      calculateNotificationBadgeCount(unreadNotificationCount: 0),
      0,
    );
  });
}
