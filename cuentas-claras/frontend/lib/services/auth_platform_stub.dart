import 'dart:io';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';

class AuthPlatform {
  static GoogleSignIn? _googleSignIn;

  static GoogleSignIn _getGoogleSignIn(String clientId) {
    return _googleSignIn ??= GoogleSignIn(
      clientId: clientId,
      serverClientId: clientId,
      scopes: const ['email', 'profile', 'openid'],
    );
  }

  static Future<void> initGis({
    required String clientId,
    required void Function(String credential) onCredential,
    required void Function(String error) onError,
  }) async {
    _googleSignIn = GoogleSignIn(
      clientId: clientId,
      serverClientId: clientId,
      scopes: const ['email', 'profile', 'openid'],
    );
  }

  static Future<void> promptGis({
    required void Function(String reason) onNotDisplayed,
    required void Function(String reason) onSkipped,
    required void Function(String reason) onDismissed,
  }) async {
    // No-op en plataformas móviles
  }

  /// Inicia sesión nativa con Google en Android/iOS usando Google Sign-In SDK.
  static Future<String?> signInNative(String clientId) async {
    final googleSignIn = _getGoogleSignIn(clientId);
    try {
      await googleSignIn.signOut();
    } catch (_) {}

    final account = await googleSignIn.signIn();
    if (account == null) {
      return null;
    }

    final auth = await account.authentication;
    return auth.idToken;
  }

  static File? _getSessionFile() {
    try {
      final dir = Directory.systemTemp;
      return File('${dir.path}/cuentas_claras_session.json');
    } catch (_) {
      return null;
    }
  }

  static String? getSavedToken(String tokenKey) {
    try {
      final file = _getSessionFile();
      if (file != null && file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        return data[tokenKey] as String?;
      }
    } catch (_) {}
    return null;
  }

  static String? getSavedUser(String userKey) {
    try {
      final file = _getSessionFile();
      if (file != null && file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        return data[userKey] as String?;
      }
    } catch (_) {}
    return null;
  }

  static void saveSession(String tokenKey, String token, String userKey, String? userJson) {
    try {
      final file = _getSessionFile();
      if (file != null) {
        file.writeAsStringSync(jsonEncode({
          tokenKey: token,
          if (userJson != null) userKey: userJson,
        }));
      }
    } catch (_) {}
  }

  static void clearSession(String tokenKey, String userKey) {
    try {
      final file = _getSessionFile();
      if (file != null && file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }
}
