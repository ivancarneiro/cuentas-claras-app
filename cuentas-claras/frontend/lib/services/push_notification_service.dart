import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'logger_service.dart';

class PushNotificationService {
  static const String _kDeviceTokenKey = 'cuentas_claras_fcm_token';
  static const String channelId = 'cuentas_claras_channel';
  static const String channelName = 'Cuentas Claras - Novedades';
  static const String channelDescription = 'Notificaciones de movimientos y grupos familiares';

  final ApiService _api;
  final LoggerService _log;
  String? _currentToken;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isLocalNotificationsInitialized = false;

  PushNotificationService({
    required ApiService api,
    LoggerService? logger,
  })  : _api = api,
        _log = logger ?? LoggerService();

  String? get currentToken => _currentToken;

  /// Inicializa el servicio de notificaciones locales y push.
  Future<void> init() async {
    _log.info('Inicializando PushNotificationService...', source: 'PushNotificationService');
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString(_kDeviceTokenKey);

      if (!kIsWeb) {
        await _initLocalNotifications();
        await requestPermissions();
      }

      if (_currentToken != null) {
        await _registerWithBackend(_currentToken!);
      }
    } catch (e) {
      _log.warning('No se pudo inicializar PushNotificationService: $e', source: 'PushNotificationService');
    }
  }

  Future<void> _initLocalNotifications() async {
    if (_isLocalNotificationsInitialized || kIsWeb) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _log.info('Notificación clickeada: ${response.payload}', source: 'PushNotificationService');
        },
      );

      // Crear canal de notificación específico para Android
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        await androidImplementation.createNotificationChannel(androidChannel);
        _log.info('Canal de notificación Android creado: $channelId', source: 'PushNotificationService');
      }

      _isLocalNotificationsInitialized = true;
    } catch (e) {
      _log.warning('Error inicializando flutter_local_notifications: $e', source: 'PushNotificationService');
    }
  }

  /// Solicita explícitamente los permisos de notificación al usuario en Android 13+ / iOS.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final granted = await androidImplementation.requestNotificationsPermission();
          _log.info('Permiso de notificaciones Android resultado: $granted', source: 'PushNotificationService');
          return granted ?? false;
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        final darwinImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        if (darwinImplementation != null) {
          final granted = await darwinImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      _log.warning('Error solicitando permisos de notificación: $e', source: 'PushNotificationService');
    }
    return false;
  }

  /// Muestra una notificación local en la barra del sistema.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      if (!_isLocalNotificationsInitialized) {
        await _initLocalNotifications();
      }

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      _log.info('Notificación local mostrada con éxito: $title', source: 'PushNotificationService');
    } catch (e) {
      _log.warning('Error mostrando notificación local: $e', source: 'PushNotificationService');
    }
  }

  /// Guarda y registra un token de dispositivo (FCM o APNs) con el backend.
  Future<void> setDeviceToken(String token, {String? platform}) async {
    _currentToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceTokenKey, token);

    String detectedPlatform = platform ?? (kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'));
    await _registerWithBackend(token, platform: detectedPlatform);
  }

  Future<void> _registerWithBackend(String token, {String platform = 'android'}) async {
    try {
      await _api.registerDeviceToken(token, platform: platform);
      _log.info('Token de dispositivo registrado exitosamente en backend', source: 'PushNotificationService');
    } catch (e) {
      _log.warning('No se pudo registrar token de dispositivo en backend: $e', source: 'PushNotificationService');
    }
  }

  /// Desregistra el token del backend al cerrar sesión.
  Future<void> unregister() async {
    if (_currentToken == null) return;
    try {
      await _api.unregisterDeviceToken(token: _currentToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDeviceTokenKey);
      _currentToken = null;
      _log.info('Token de dispositivo desregistrado exitosamente', source: 'PushNotificationService');
    } catch (e) {
      _log.warning('Error desregistrando token: $e', source: 'PushNotificationService');
    }
  }
}
