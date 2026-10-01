import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/auth_platform.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final LoggerService _log;

  /// Completer to bridge the GIS callback with async signInWithGoogle.
  Completer<String>? _pendingCredential;

  /// Whether GIS has been initialized.
  bool _gisInitialized = false;

  bool _isLoading = false;
  String? _token;
  Map<String, dynamic>? _user;
  String? _error;

  static const String _tokenKey = 'cuentas_claras_token';
  static const String _userKey = 'cuentas_claras_user';

  AuthProvider(this._api, {LoggerService? logger})
      : _log = logger ?? LoggerService() {
    _log.info('AuthProvider inicializado', source: 'AuthProvider');
    _log.info('Backend URL: ${ApiConfig.baseUrl}', source: 'AuthProvider');
    _log.info(
        'Google Client ID: ${_maskClientId(ApiConfig.googleClientId)}',
        source: 'AuthProvider');
    _log.info('Plataforma: ${kIsWeb ? "Web" : "Móvil"}', source: 'AuthProvider');

    _api.onUnauthorized = () {
      _log.warning('⚠️ Sesión expirada o no autorizada (401). Cerrando sesión...',
          source: 'AuthProvider');
      logout();
    };

    _tryRestoreSession();

    if (kIsWeb) {
      _initGis();
    }
  }

  Future<void> _validateSession() async {
    if (_token == null) return;
    try {
      final me = await _api.getMe();
      _user = me;
      _persistSession();
      _log.info('✅ Sesión validada con backend — user=${me['name']} (${me['email']})',
          source: 'AuthProvider._validateSession');
      notifyListeners();
    } catch (e) {
      _log.warning('⚠️ Error al validar sesión con backend: $e. Cerrando sesión.',
          source: 'AuthProvider._validateSession');
      logout();
    }
  }

  /// Try to restore a saved session from localStorage (web) or local file (mobile).
  void _tryRestoreSession() {
    try {
      final savedToken = AuthPlatform.getSavedToken(_tokenKey);
      final savedUser = AuthPlatform.getSavedUser(_userKey);
      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        _api.setToken(_token);
        if (savedUser != null && savedUser.isNotEmpty) {
          _user = jsonDecode(savedUser) as Map<String, dynamic>?;
        }
        _log.info('✅ Sesión restaurada — userId=${_user?['id']} name=${_user?['name']}',
            source: 'AuthProvider._tryRestoreSession');
        _validateSession();
      }
    } catch (e) {
      _log.warning('⚠️ Error al restaurar sesión: $e',
          source: 'AuthProvider._tryRestoreSession');
      // If restoration fails, clear corrupted data
      _clearSession();
    }
  }

  /// Save the current session.
  void _persistSession() {
    try {
      if (_token != null) {
        AuthPlatform.saveSession(_tokenKey, _token!, _userKey, _user != null ? jsonEncode(_user) : null);
        _log.debug('✅ Sesión persistida',
            source: 'AuthProvider._persistSession');
      }
    } catch (e) {
      _log.warning('⚠️ Error al persistir sesión: $e',
          source: 'AuthProvider._persistSession');
    }
  }

  /// Clear session data.
  void _clearSession() {
    try {
      AuthPlatform.clearSession(_tokenKey, _userKey);
      _log.debug('🗑️ Sesión eliminada',
          source: 'AuthProvider._clearSession');
    } catch (e) {
      _log.warning('⚠️ Error al limpiar sesión: $e',
          source: 'AuthProvider._clearSession');
    }
  }

  bool get isLoading => _isLoading;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;
  bool get isLoggedIn => _token != null;
  ApiService get api => _api;

  Future<Map<String, dynamic>?> checkAppVersion(String currentVersion) {
    return _api.checkAppVersion(currentVersion);
  }

  String get userName => _user?['name'] ?? '';
  int get userId => _user?['id'] ?? 0;
  bool get hasError => _error != null;

  /// Mask a client ID for safe logging (show first/last chars).
  String _maskClientId(String id) {
    if (id.length <= 20) return id;
    return '${id.substring(0, 15)}...${id.substring(id.length - 10)}';
  }

  /// Initialize Google Identity Services (GIS) Sign-In.
  void _initGis() {
    try {
      AuthPlatform.initGis(
        clientId: ApiConfig.googleClientId,
        onCredential: _onCredentialReceived,
        onError: (errorMsg) {
          _log.error('❌ GIS Sign-In error: $errorMsg',
              source: 'AuthProvider._initGis');
          _error = 'Error en Google Sign-In: $errorMsg';
          _isLoading = false;
          notifyListeners();

          if (_pendingCredential != null && !_pendingCredential!.isCompleted) {
            _pendingCredential!.completeError(errorMsg);
          }
        },
      );
      _gisInitialized = true;
      _log.info('✅ GIS Sign-In inicializado',
          source: 'AuthProvider._initGis');
    } catch (e) {
      _log.error('❌ Error al inicializar GIS Sign-In: $e',
          source: 'AuthProvider._initGis', exception: e);
    }
  }

  void _onCredentialReceived(String credential) async {
    _log.info('✅ Credential (ID token) recibido (${credential.length} chars)',
        source: 'AuthProvider._onCredentialReceived');
    
    if (_pendingCredential != null && !_pendingCredential!.isCompleted) {
      _pendingCredential!.complete(credential);
    } else {
      // Flujo del botón oficial de Google directo (sin pending credential)
      _log.info('🔵 Iniciando sesión directa con Google...',
          source: 'AuthProvider._onCredentialReceived');
      _isLoading = true;
      _error = null;
      notifyListeners();

      try {
        final data = await _api.googleLogin(credential);
        _token = data['token'] as String?;
        _user = data['user'] as Map<String, dynamic>?;
        _api.setToken(_token);
        _persistSession();
        _isLoading = false;
        notifyListeners();
        _log.info('✅ Google login directo exitoso',
            source: 'AuthProvider._onCredentialReceived');
      } catch (e) {
        _log.error('❌ Error en login directo con Google: $e',
            source: 'AuthProvider._onCredentialReceived', exception: e);
        _error = 'Error al verificar credenciales de Google con el servidor.';
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Quick pre-flight check of configuration.
  String _checkConfig() {
    final hasClientId = ApiConfig.googleClientId.isNotEmpty &&
        ApiConfig.googleClientId != 'TU_CLIENT_ID.apps.googleusercontent.com';
    return 'Client ID configurado: $hasClientId\n'
        'Client ID: ${_maskClientId(ApiConfig.googleClientId)}\n'
        'Backend: ${ApiConfig.baseUrl}\n'
        'Web: $kIsWeb\n'
        'GIS inicializado: $_gisInitialized';
  }

  /// Sign in with Google using GIS Sign-In API.
  Future<bool> signInWithGoogle() async {
    _log.info('🔵 Google Sign-In iniciando...',
        source: 'AuthProvider.signInWithGoogle');

    final diag = _checkConfig();
    _log.debug('Config:\n$diag', source: 'AuthProvider.signInWithGoogle');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? idToken;
      if (kIsWeb) {
        if (!_gisInitialized) {
          _initGis();
          if (!_gisInitialized) {
            throw Exception('GIS no disponible en este navegador');
          }
        }

        // Create a fresh completer for this login attempt
        _pendingCredential = Completer<String>();

        // Trigger the Google Sign-In popup
        _log.debug('Llamando AuthPlatform.promptGis()...',
            source: 'AuthProvider.signInWithGoogle');
        AuthPlatform.promptGis(
          onNotDisplayed: (reason) {
            _log.warning('⚠️ GIS prompt no se mostró: $reason',
                source: 'AuthProvider.signInWithGoogle');
          },
          onSkipped: (reason) {
            _log.warning('⚠️ GIS prompt saltado: $reason',
                source: 'AuthProvider.signInWithGoogle');
          },
          onDismissed: (reason) {
            _log.warning('⚠️ GIS prompt descartado: $reason',
                source: 'AuthProvider.signInWithGoogle');
          },
        );

        // Wait for the credential (with timeout)
        _log.debug('Esperando respuesta de GIS...',
            source: 'AuthProvider.signInWithGoogle');
        idToken = await _pendingCredential!.future
            .timeout(const Duration(seconds: 60));
      } else {
        // En Android / Móvil nativo
        _log.info('Iniciando Google Sign-In nativo en Android...',
            source: 'AuthProvider.signInWithGoogle');
        idToken = await AuthPlatform.signInNative(ApiConfig.googleClientId);
        if (idToken == null) {
          _log.info('Google Sign-In cancelado por el usuario',
              source: 'AuthProvider.signInWithGoogle');
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      _log.info(
          '✅ ID token obtenido (${idToken.length} chars). Enviando al backend...',
          source: 'AuthProvider.signInWithGoogle');

      final data = await _api.googleLogin(idToken);

      _log.info('✅ Google login exitoso',
          source: 'AuthProvider.signInWithGoogle',
          details: {
            'userId': data['user']?['id'],
            'name': data['user']?['name']
          });

      _token = data['token'] as String?;
      _user = data['user'] as Map<String, dynamic>?;
      _api.setToken(_token);
      _persistSession();
      _isLoading = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      _log.warning('⏱️ Google Sign-In: tiempo de espera agotado (60s)',
          source: 'AuthProvider.signInWithGoogle');
      _error = 'Se agotó el tiempo de espera.\n'
          'Si la ventana de Google no apareció, verificá que no esté bloqueada\n'
          'por el navegador o una extensión.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      final errorStr = e.toString();
      _log.error('❌ Error en signInWithGoogle: $errorStr',
          source: 'AuthProvider.signInWithGoogle', exception: e);

      // Determine the specific error type for a helpful message
      if (errorStr.contains('popup_closed') ||
          errorStr.contains('user_cancel')) {
        _error = 'Ventana de Google cerrada antes de completar '
            'el inicio de sesión.';
      } else if (errorStr.contains('popup_failed_to_open') ||
          errorStr.contains('blocked')) {
        _error = 'El navegador bloqueó la ventana emergente de Google.\n'
            'Permití ventanas emergentes (popups) para este sitio.\n'
            '🔧 En Chrome: hacé clic en el ícono 🔒 en la barra de direcciones '
            'y activá "Pop-ups".';
      } else if (errorStr.contains('access_denied') ||
          errorStr.contains('access denied')) {
        _error = 'Acceso denegado. No diste permisos a la aplicación.';
      } else if (errorStr.contains('SocketException') ||
          errorStr.contains('Connection refused')) {
        _error = 'No se puede conectar al servidor.\n'
            'Verificá que el backend esté corriendo en ${ApiConfig.baseUrl}.';
      } else if (errorStr.contains('ApiException')) {
        _error = 'Error del servidor: ${e is ApiException ? e.message : errorStr}';
      } else {
        final maxLen = 300;
        final trimmed = errorStr.length > maxLen
            ? '${errorStr.substring(0, maxLen)}...'
            : errorStr;
        _error = 'Error al iniciar sesión con Google.\n'
            'Detalle técnico:\n$trimmed';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fallback login with email/password (quick access chips).
  Future<bool> login(String email, String password) async {
    _log.info('🔵 Login (email/password) — email=$email',
        source: 'AuthProvider.login');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _log.debug('URL del backend: ${ApiConfig.baseUrl}/auth/login',
          source: 'AuthProvider.login');

      final data = await _api.login(email, password);

      _log.info(
          '✅ Login exitoso — userId=${data['user']?['id']} '
          'name=${data['user']?['name']}',
          source: 'AuthProvider.login');

      _token = data['token'] as String?;
      _user = data['user'] as Map<String, dynamic>?;
      _api.setToken(_token);
      _persistSession();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final errorStr = e.toString();
      _log.error('❌ Error en login: $errorStr',
          source: 'AuthProvider.login', exception: e);

      if (errorStr.contains('SocketException') ||
          errorStr.contains('Connection refused')) {
        _error = 'No se puede conectar al servidor.\n'
            'Verificá que el backend esté corriendo en ${ApiConfig.baseUrl}.';
      } else if (errorStr.contains('ApiException')) {
        _error = 'Error: ${e is ApiException ? e.message : errorStr}';
      } else {
        _error = 'Error de conexión. Revisá si el backend está funcionando.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _log.info('Actualizando perfil...', source: 'AuthProvider.updateProfile');
    try {
      final result = await _api.updateProfile(data);
      _user = result as Map<String, dynamic>?;
      _persistSession();
      notifyListeners();
      return true;
    } catch (e) {
      _log.error('Error al actualizar perfil: $e', source: 'AuthProvider.updateProfile', exception: e);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _log.info('Cerrando sesión...', source: 'AuthProvider.logout');
    _pendingCredential = null;
    _token = null;
    _user = null;
    _api.setToken(null);
    _error = null;
    _clearSession();
    _log.info('Sesión cerrada', source: 'AuthProvider.logout');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
