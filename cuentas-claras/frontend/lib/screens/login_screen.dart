import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/google_signin_button.dart';
import '../widgets/server_config_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPasswordForm = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Configurar servidor backend',
            onPressed: () => ServerConfigDialog.show(context, onServerChanged: () {
              setState(() {});
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo area
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 50,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cuentas Claras',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Controlá tus finanzas familiares y personales',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 36),


                // Error message
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.error != null) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.expenseColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              auth.error!,
                              style: const TextStyle(color: AppTheme.expenseColor, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => ServerConfigDialog.show(context, onServerChanged: () => setState(() {})),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.dns_outlined, size: 14, color: AppTheme.expenseColor),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verificar servidor backend',
                                      style: TextStyle(
                                        color: AppTheme.expenseColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Google Sign-In button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isLoading) {
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: AppTheme.grey300(context),
                              width: 1.5,
                            ),
                            backgroundColor: AppTheme.surface(context),
                          ),
                          icon: const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: Text(
                            'Iniciando sesión...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    if (kIsWeb) {
                      return const Center(
                        child: GoogleSignInButton(),
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => _signIn(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: AppTheme.grey300(context),
                            width: 1.5,
                          ),
                          backgroundColor: AppTheme.surface(context),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        icon: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                        ),
                        label: Text(
                          'Ingresar con Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Toggle para login tradicional con email/contraseña
                if (!_showPasswordForm)
                  TextButton.icon(
                    onPressed: () => setState(() => _showPasswordForm = true),
                    icon: const Icon(Icons.mail_outline, size: 16),
                    label: const Text(
                      'O ingresar con usuario y contraseña',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                else ...[
                  // Separador
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.grey300(context).withValues(alpha: 0.5))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Acceso con cuenta',
                          style: TextStyle(fontSize: 12, color: AppTheme.grey500(context)),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.grey300(context).withValues(alpha: 0.5))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Input Contraseña
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón Iniciar Sesión con email/password
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => _emailLogin(context),
                      child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

              const SizedBox(height: 28),

              // Indicador discreto del servidor configurado
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => ServerConfigDialog.show(context, onServerChanged: () => setState(() {})),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_outlined, size: 13, color: AppTheme.grey500(context)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Servidor: ${ApiConfig.baseUrl}',
                          style: TextStyle(fontSize: 11, color: AppTheme.grey500(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 11, color: AppTheme.grey500(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await auth.signInWithGoogle();
  }

  Future<void> _emailLogin(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    await auth.login(email, password);
  }
}
