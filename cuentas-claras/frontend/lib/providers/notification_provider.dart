import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/push_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  final LoggerService _log;
  final PushNotificationService? _pushService;

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollTimer;
  int? _lastNotifiedId;

  NotificationProvider({
    required ApiService api,
    LoggerService? logger,
    PushNotificationService? pushService,
  })  : _api = api,
        _log = logger ?? LoggerService(),
        _pushService = pushService;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void startPolling({Duration interval = const Duration(seconds: 45)}) {
    _pollTimer?.cancel();
    refreshUnreadCount();
    _pollTimer = Timer.periodic(interval, (_) {
      refreshUnreadCount();
    });
    _log.info('Polling de notificaciones iniciado', source: 'NotificationProvider');
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _log.info('Polling de notificaciones detenido', source: 'NotificationProvider');
  }

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _api.getUnreadNotificationCount();
      if (_unreadCount != count) {
        final previousCount = _unreadCount;
        _unreadCount = count;
        notifyListeners();

        // Si llegaron nuevas notificaciones no leídas, mostrar notificación en el sistema Android/iOS
        if (count > previousCount) {
          await _triggerLatestSystemNotification();
        }
      }
    } catch (e) {
      _log.warning('Error refrescando conteo de notificaciones: $e', source: 'NotificationProvider');
    }
  }

  Future<void> _triggerLatestSystemNotification() async {
    try {
      final data = await _api.getNotifications(page: 1, limit: 1);
      final rawList = data['notifications'] as List<dynamic>? ?? [];
      if (rawList.isNotEmpty) {
        final latest = NotificationItem.fromJson(rawList.first as Map<String, dynamic>);
        if (!latest.isRead && latest.id != _lastNotifiedId) {
          _lastNotifiedId = latest.id;
          await _pushService?.showLocalNotification(
            id: latest.id,
            title: latest.title,
            body: latest.message,
            payload: latest.type,
          );
        }
      }
    } catch (e) {
      _log.warning('Error disparando notificación de sistema: $e', source: 'NotificationProvider');
    }
  }

  Future<void> loadNotifications({bool refresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    if (refresh) notifyListeners();

    try {
      final data = await _api.getNotifications(page: 1, limit: 100);
      final rawList = data['notifications'] as List<dynamic>? ?? [];
      _notifications = rawList
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();
      _unreadCount = (data['unread_count'] as num?)?.toInt() ?? 0;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _log.error('Error cargando notificaciones: $e', source: 'NotificationProvider');
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }

    try {
      await _api.markNotificationRead(id);
    } catch (e) {
      _log.error('Error marcando notificación como leída: $e', source: 'NotificationProvider');
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await _api.markAllNotificationsRead();
    } catch (e) {
      _log.error('Error marcando todas las notificaciones como leídas: $e', source: 'NotificationProvider');
    }
  }

  Future<void> deleteNotification(int id) async {
    final removed = _notifications.firstWhere(
      (n) => n.id == id,
      orElse: () => NotificationItem(
        id: -1,
        userId: -1,
        title: '',
        message: '',
        type: '',
        isRead: true,
      ),
    );

    if (removed.id != -1 && !removed.isRead && _unreadCount > 0) {
      _unreadCount--;
    }
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();

    try {
      await _api.deleteNotification(id);
    } catch (e) {
      _log.error('Error eliminando notificación: $e', source: 'NotificationProvider');
    }
  }

  void clear() {
    stopPolling();
    _notifications = [];
    _unreadCount = 0;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
