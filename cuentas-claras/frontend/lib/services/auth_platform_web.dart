import 'dart:html' as html;
import 'package:google_identity_services_web/id.dart' as gis_id;

class AuthPlatform {
  static Future<void> initGis({
    required String clientId,
    required void Function(String credential) onCredential,
    required void Function(String error) onError,
  }) async {
    gis_id.id.initialize(gis_id.IdConfiguration(
      client_id: clientId,
      callback: (gis_id.CredentialResponse response) {
        if (response.error != null) {
          onError(response.error_detail ?? response.error!);
        } else if (response.credential != null && response.credential!.isNotEmpty) {
          onCredential(response.credential!);
        } else {
          onError('Google no devolvió credenciales válidas.');
        }
      },
      auto_select: false,
      cancel_on_tap_outside: false,
      ux_mode: gis_id.UxMode.popup,
    ));
  }

  static Future<void> promptGis({
    required void Function(String reason) onNotDisplayed,
    required void Function(String reason) onSkipped,
    required void Function(String reason) onDismissed,
  }) async {
    gis_id.id.prompt((moment) {
      if (moment.isNotDisplayed()) {
        onNotDisplayed(moment.getNotDisplayedReason()?.toString() ?? 'unknown');
      } else if (moment.isSkippedMoment()) {
        onSkipped(moment.getSkippedReason()?.toString() ?? 'unknown');
      } else if (moment.isDismissedMoment()) {
        onDismissed(moment.getDismissedReason()?.toString() ?? 'unknown');
      }
    });
  }

  static Future<String?> signInNative(String clientId) async {
    return null;
  }

  static String? getSavedToken(String tokenKey) {
    try {
      return html.window.localStorage[tokenKey];
    } catch (_) {
      return null;
    }
  }

  static String? getSavedUser(String userKey) {
    try {
      return html.window.localStorage[userKey];
    } catch (_) {
      return null;
    }
  }

  static void saveSession(String tokenKey, String token, String userKey, String? userJson) {
    try {
      html.window.localStorage[tokenKey] = token;
      if (userJson != null) {
        html.window.localStorage[userKey] = userJson;
      }
    } catch (_) {}
  }

  static void clearSession(String tokenKey, String userKey) {
    try {
      html.window.localStorage.remove(tokenKey);
      html.window.localStorage.remove(userKey);
    } catch (_) {}
  }
}
