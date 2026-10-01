import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/data_provider.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isAuthorizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().loadAdminData();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, _) {
        final users = data.adminUsers;
        final authorized = data.authorizedEmails;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Administración de Usuarios'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: () => data.loadAdminData(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => data.loadAdminData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Tarjeta: Autorizar Nuevo Usuario ─────────────────
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person_add_alt_1_rounded,
                                  color: AppTheme.primaryColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Habilitar Usuario Individual',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Permití que un usuario ingrese con su cuenta de Google para gestionar sus finanzas de forma independiente.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico de Google',
                            hintText: 'ejemplo@gmail.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Nota o nombre (opcional)',
                            hintText: 'Ej: Compañero de trabajo',
                            prefixIcon: Icon(Icons.notes_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isAuthorizing ? null : () => _submitAuthorize(data),
                            icon: _isAuthorizing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Habilitar Acceso'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Sección: Correos Pre-Autorizados Pendientes ───────
                if (authorized.isNotEmpty) ...[
                  _buildSectionTitle('Correos Autorizados (Pendientes de registro)', count: authorized.length),
                  const SizedBox(height: 8),
                  ...authorized.map((a) => _buildAuthorizedEmailCard(context, a, data)),
                  const SizedBox(height: 24),
                ],

                // ── Sección: Usuarios Registrados ────────────────────
                _buildSectionTitle('Usuarios en la Plataforma', count: users.length),
                const SizedBox(height: 8),
                if (users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No hay usuarios cargados',
                        style: TextStyle(color: AppTheme.textSecondary(context)),
                      ),
                    ),
                  )
                else
                  ...users.map((u) => _buildUserCard(context, u, data)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, {required int count}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary(context),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorizedEmailCard(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    final id = item['id'] as int;
    final email = item['email'] as String? ?? '';
    final notes = item['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          child: const Icon(Icons.mark_email_unread_outlined, color: Colors.orange, size: 20),
        ),
        title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: notes != null && notes.isNotEmpty
            ? Text(notes, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)))
            : Text('Pendiente de primer login', style: TextStyle(fontSize: 12, color: AppTheme.grey400(context))),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.expenseColor, size: 20),
          tooltip: 'Revocar autorización',
          onPressed: () => _confirmRevoke(context, data, id, email),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user, DataProvider data) {
    final id = user['id'] as int;
    final name = user['name'] as String? ?? 'Sin nombre';
    final email = user['email'] as String? ?? '';
    final isActive = user['is_active'] as bool? ?? true;
    final isOwner = user['is_app_owner'] as bool? ?? false;
    final photoUrl = user['photo_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isActive
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppTheme.primaryColor : Colors.grey,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isActive ? AppTheme.textPrimary(context) : AppTheme.grey400(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.savingsColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Dueño',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.savingsColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOwner)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.savingsColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Activo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.savingsColor)),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: isActive,
                    activeColor: AppTheme.savingsColor,
                    inactiveThumbColor: AppTheme.expenseColor,
                    onChanged: (val) async {
                      await data.toggleUserStatus(id);
                    },
                  ),
                  Text(
                    isActive ? 'Habilitado' : 'Deshabilitado',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppTheme.savingsColor : AppTheme.expenseColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _submitAuthorize(DataProvider data) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un correo electrónico válido')),
      );
      return;
    }

    setState(() => _isAuthorizing = true);
    final success = await data.authorizeEmail(email, notes: _notesController.text.trim());
    setState(() => _isAuthorizing = false);

    if (mounted) {
      if (success) {
        _emailController.clear();
        _notesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario $email autorizado exitosamente'),
            backgroundColor: AppTheme.savingsColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data.error ?? 'Error al autorizar correo'),
            backgroundColor: AppTheme.expenseColor,
          ),
        );
      }
    }
  }

  void _confirmRevoke(BuildContext context, DataProvider data, int id, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar autorización'),
        content: Text('¿Seguro que deseás revocar el acceso para $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await data.revokeAuthorizedEmail(id);
            },
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
  }
}
