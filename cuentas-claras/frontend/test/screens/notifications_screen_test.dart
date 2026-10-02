import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cuentas_claras_app/providers/notification_provider.dart';
import 'package:cuentas_claras_app/screens/notifications_screen.dart';
import 'package:cuentas_claras_app/services/api_service.dart';

class FakeApiService extends ApiService {
  List<Map<String, dynamic>> fakeNotifications = [];
  int unread = 0;

  @override
  Future<Map<String, dynamic>> getNotifications({int page = 1, int limit = 50}) async {
    return {
      'notifications': fakeNotifications,
      'total': fakeNotifications.length,
      'unread_count': unread,
    };
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    return unread;
  }

  @override
  Future<Map<String, dynamic>> markNotificationRead(int id) async {
    final item = fakeNotifications.firstWhere((n) => n['id'] == id);
    item['is_read'] = true;
    if (unread > 0) unread--;
    return {'message': 'Marked as read'};
  }

  @override
  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    for (var n in fakeNotifications) {
      n['is_read'] = true;
    }
    unread = 0;
    return {'message': 'All marked as read'};
  }

  @override
  Future<void> deleteNotification(int id) async {
    fakeNotifications.removeWhere((n) => n['id'] == id);
  }
}

void main() {
  late FakeApiService fakeApi;
  late NotificationProvider notifProvider;

  setUp(() {
    fakeApi = FakeApiService();
    notifProvider = NotificationProvider(api: fakeApi);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ChangeNotifierProvider<NotificationProvider>.value(
        value: notifProvider,
        child: const NotificationsScreen(),
      ),
    );
  }

  testWidgets('Renders empty state when there are no notifications', (tester) async {
    fakeApi.fakeNotifications = [];
    fakeApi.unread = 0;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Todo al día'), findsOneWidget);
    expect(find.text('Te avisaremos cuando haya nuevos movimientos o cambios en tus grupos.'), findsOneWidget);
  });

  testWidgets('Renders notification list and mark as read works', (tester) async {
    fakeApi.fakeNotifications = [
      {
        'id': 101,
        'user_id': 1,
        'actor_id': 2,
        'actor_name': 'Carlos Perez',
        'actor_short_name': 'Carlos',
        'household_id': 5,
        'household_name': 'Casa Central',
        'title': 'Nuevo gasto registrado',
        'message': 'Carlos agregó un gasto de \$5.000 en Supermercado',
        'type': 'transaction_created',
        'reference_id': 42,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      },
    ];
    fakeApi.unread = 1;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Nuevo gasto registrado'), findsOneWidget);
    expect(find.text('Carlos agregó un gasto de \$5.000 en Supermercado'), findsOneWidget);
    expect(find.text('Casa Central'), findsOneWidget);
    expect(find.text('1 sin leer'), findsOneWidget);

    // Tap notification to mark as read
    await tester.tap(find.text('Nuevo gasto registrado'));
    await tester.pumpAndSettle();

    expect(notifProvider.notifications.first.isRead, isTrue);
    expect(notifProvider.unreadCount, 0);
  });
}
