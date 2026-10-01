import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConfig {
  // En desarrollo web usa localhost:5000/api. En producción (Vercel) usa '/api' relativo.
  // En mobile release usa la URL completa de producción en Vercel.
  static String get baseUrl {
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
    if (kReleaseMode) {
      return 'https://cuentas-claras-rouge.vercel.app/api';
    }
    return 'http://10.0.2.2:5000/api';
  }

  /// Google OAuth Client ID for Web
  /// Create one at https://console.cloud.google.com/apis/credentials
  /// 1. Create a project
  /// 2. Go to APIs & Services > Credentials
  /// 3. Create OAuth client ID > Web application
  /// 4. Add your app URL to Authorized JavaScript origins
  /// 5. Copy the Client ID here
  static const String googleClientId = '700638175128-ferq5uqn2ateaonkcls1pggv26einels.apps.googleusercontent.com';

  static const String currentVersion = '1.0.5';

  static const Duration timeout = Duration(seconds: 30);
}

