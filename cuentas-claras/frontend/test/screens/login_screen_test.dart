import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cuentas_claras_app/screens/login_screen.dart';
import 'package:cuentas_claras_app/providers/auth_provider.dart';
import 'package:cuentas_claras_app/services/api_service.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {

  @override
  bool isLoading = false;

  @override
  String? error;

  @override
  Map<String, dynamic>? user;

  @override
  bool get isLoggedIn => user != null;

  @override
  String get userName => user?['name'] ?? '';

  @override
  int get userId => user?['id'] ?? 0;

  @override
  bool get hasError => error != null;

  @override
  String? get token => 'fake_token';

  bool googleSignInCalled = false;
  bool loginCalled = false;
  String? lastLoginEmail;

  @override
  Future<bool> signInWithGoogle() async {
    googleSignInCalled = true;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> login(String email, String password) async {
    loginCalled = true;
    lastLoginEmail = email;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> updateProfile(Map<String, dynamic> data) async => true;

  @override
  Future<void> logout() async {}

  @override
  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  ApiService get api => ApiService();

  @override
  Future<Map<String, dynamic>?> checkAppVersion(String currentVersion) async => null;
}


void main() {
  late FakeAuthProvider fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthProvider();
  });

  Widget buildTestWidget() {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: fakeAuth,
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  testWidgets('LoginScreen renders main elements', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Verify title and subtitle
    expect(find.text('Cuentas Claras'), findsOneWidget);
    expect(find.text('Controlá tus finanzas familiares y personales'), findsOneWidget);

    // Verify Google login button
    expect(find.text('Ingresar con Google'), findsOneWidget);
  });

  testWidgets('LoginScreen shows loading state', (WidgetTester tester) async {
    fakeAuth.isLoading = true;
    await tester.pumpWidget(buildTestWidget());

    // Verify button shows loading text
    expect(find.text('Iniciando sesión...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LoginScreen shows error message when present', (WidgetTester tester) async {
    fakeAuth.error = 'Error de conexión de prueba';
    await tester.pumpWidget(buildTestWidget());

    // Verify error text is displayed
    expect(find.text('Error de conexión de prueba'), findsOneWidget);
  });

  testWidgets('Clicking Google button calls signInWithGoogle', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Tap on the Google sign in button
    await tester.tap(find.text('Ingresar con Google'));
    await tester.pump();

    expect(fakeAuth.googleSignInCalled, true);
  });
}

