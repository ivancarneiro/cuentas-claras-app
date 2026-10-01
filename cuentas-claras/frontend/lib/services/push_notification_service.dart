import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'logger_service.dart';

class PushNotificationService {
  static const String _kDeviceTokenKey = 'cuentas_claras_fcm_token';

  final ApiService _api;
  final LoggerService _log;
  String? _currentToken;

  PushNotificationService({
    required ApiService api,
    LoggerService? logger,
  })  : _api = api,
        _log = logger ?? LoggerService();

  String? get currentToken => _currentToken;

  /// Inicializa el servicio de notificaciones push.
  Future<void> init() async {
    _log.info('Inicializando PushNotificationService...', source: 'PushNotificationService');
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString(_kDeviceTokenKey);

      // Si ya hay un token guardado previamente y sesión activa, asegurar registro con backend
      if (_currentToken != null) {
        await _registerWithBackend(_currentToken!);
      }
    } catch (e) {
      _log.warning('No se pudo inicializar PushNotificationService: $e', source: 'PushNotificationService');
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
