import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_avatar.dart';
import 'admin_users_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _shortNameController;
  bool _isSaving = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.userName);
    _emailController = TextEditingController(text: auth.user?['email'] ?? '');
    _shortNameController = TextEditingController(text: auth.user?['short_name'] ?? '');
    _photoUrl = auth.user?['photo_url'] as String?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'short_name': _shortNameController.text.trim().toUpperCase(),
      'photo_url': _photoUrl ?? '', // Send empty string to clear photo
    };

    final success = await auth.updateProfile(payload);
    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Photo section
              Center(
                child: GestureDetector(
                  onTap: _photoUrl == null ? null : () => _showPhotoFullscreen(context),
                  child: Stack(
                    children: [
                      UserAvatar(
                        radius: 50,
                        name: _nameController.text.isNotEmpty ? _nameController.text : auth.userName,
                        photoUrl: _photoUrl,
                        userId: auth.userId,
                        fontSize: 40,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                          ),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_photoUrl != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _photoUrl = null);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar foto'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.expenseColor),
                ),
              const SizedBox(height: 32),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Short name (initials)
              TextFormField(
                controller: _shortNameController,
                decoration: const InputDecoration(
                  labelText: 'Iniciales (opcional)',
                  prefixIcon: Icon(Icons.short_text),
                  hintText: 'Ej: I, T, JM',
                ),
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // Info card
              Card(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Si usaste Google, la foto se importa automáticamente.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (auth.user?['is_app_owner'] == true) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    title: const Text(
                      'Administración de Usuarios',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Habilitar usuarios, autorizar cuentas Google y gestionar accesos.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoFullscreen(BuildContext context) {
    if (_photoUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(_photoUrl!, height: 300, width: 300, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
