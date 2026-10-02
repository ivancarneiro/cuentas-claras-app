import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyCustomUrl = 'custom_backend_url';
  static String? _customBaseUrl;

  /// Carga la URL personalizada desde SharedPreferences al iniciar la app.
  static Future<void> loadCustomBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customBaseUrl = prefs.getString(_keyCustomUrl);
    } catch (_) {}
  }

  /// Guarda una nueva URL personalizada para el backend.
  static Future<void> setCustomBaseUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null || url.trim().isEmpty) {
        _customBaseUrl = null;
        await prefs.remove(_keyCustomUrl);
      } else {
        String clean = url.trim();
        if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
          clean = 'https://$clean';
        }
        while (clean.endsWith('/')) {
          clean = clean.substring(0, clean.length - 1);
        }
        if (!clean.endsWith('/api')) {
          clean = '$clean/api';
        }
        _customBaseUrl = clean;
        await prefs.setString(_keyCustomUrl, clean);
      }
    } catch (_) {}
  }

  /// Retorna si el usuario ha configurado manualmente una URL de backend.
  static bool get isCustomUrlSet => _customBaseUrl != null && _customBaseUrl!.isNotEmpty;

  /// URL base para todas las llamadas a la API REST.
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }
    if (kIsWeb) {
      if (kReleaseMode) {
        return '${Uri.base.origin}/api';
      }
      return 'http://localhost:5000/api';
    }
    // En mobile default: fallback local agnóstico
    return 'http://10.0.2.2:5000/api';
  }

  /// Google OAuth Client ID for Web
  static const String googleClientId = '700638175128-ferq5uqn2ateaonkcls1pggv26einels.apps.googleusercontent.com';

  static const String currentVersion = '1.0.9';

  static const Duration timeout = Duration(seconds: 30);
}
