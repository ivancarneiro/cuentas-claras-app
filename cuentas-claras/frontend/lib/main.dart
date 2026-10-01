import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'config/theme.dart';
import 'services/api_service.dart';
import 'services/logger_service.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/debug_overlay.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.loadCustomBaseUrl();
  runApp(const CuentasClarasApp());
}

class CuentasClarasApp extends StatelessWidget {
  const CuentasClarasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final loggerService = LoggerService(maxEntries: 500);
    final apiService = ApiService(logger: loggerService);

    loggerService.info('🧪 Cuentas Claras App iniciando', source: 'main');
    loggerService.info('📡 Backend URL: ${ApiConfig.baseUrl}', source: 'main');
    loggerService.info('🔑 Google Client ID: ${ApiConfig.googleClientId.substring(0, 30)}...',
        source: 'main');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: loggerService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService, logger: loggerService)),
        ChangeNotifierProvider(create: (_) => DataProvider(apiService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(api: apiService, logger: loggerService)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Cuentas Claras',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const DebugOverlay(
              child: AuthGate(),
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: [
              Locale('es', 'AR'),
              Locale('en', 'US'),
            ],
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkedForUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (_checkedForUpdates) return;
    _checkedForUpdates = true;

    // Solo verificamos en Android / plataformas móviles nativas, no en Web
    if (kIsWeb) return;

    try {
      final auth = context.read<AuthProvider>();
      final updateInfo = await auth.checkAppVersion(ApiConfig.currentVersion);
      if (updateInfo != null && updateInfo['update_required'] == true && mounted) {
        final latestVersion = updateInfo['latest_version'] as String? ?? '1.0.0';
        final downloadUrl = updateInfo['download_url'] as String? ?? ApiConfig.baseUrl;
        final releaseNotes = updateInfo['release_notes'] as String?;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => UpdateDialog(
            latestVersion: latestVersion,
            currentVersion: ApiConfig.currentVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoggedIn) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

