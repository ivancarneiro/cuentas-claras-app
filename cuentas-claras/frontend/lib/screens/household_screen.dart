import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/data_provider.dart';
import '../providers/auth_provider.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = context.read<DataProvider>();
      data.loadHouseholds();
      data.loadPendingInvitations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Grupos'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Crear grupo',
                onPressed: () => _showCreateHouseholdDialog(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await data.loadHouseholds();
              await data.loadPendingInvitations();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Pending invitations
                if (data.pendingInvitations.isNotEmpty) ...[
                  _SectionHeader(title: 'Invitaciones Pendientes'),
                  ...data.pendingInvitations.map((inv) => _buildInvitationCard(context, inv, data)),
                  const SizedBox(height: 16),
                ],

                // Households
                _SectionHeader(title: 'Mis Grupos'),
                if (data.households.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.group_outlined, size: 64, color: AppTheme.grey300(context)),
                          const SizedBox(height: 16),
                          Text('No hay grupos',
                              style: TextStyle(color: AppTheme.grey500(context))),
                          const SizedBox(height: 8),
                          Text('Creá un grupo o aceptá una invitación',
                              style: TextStyle(color: AppTheme.grey400(context))),
                        ],
                      ),
                    ),
                  )
                else
                  ...data.households.map((h) => _buildHouseholdCard(context, h, data)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Invitation card ─────────────────────────────────────────────

  Widget _buildInvitationCard(BuildContext context, Map<String, dynamic> inv, DataProvider data) {
    final token = inv['token'] as String?;
    final householdName = inv['household_name'] as String? ?? 'Un grupo';
    final invitedBy = inv['invited_by_name'] as String? ?? 'Alguien';
    final role = inv['role'] as String? ?? 'read';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mail_outline, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invitación a $householdName',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary(context))),
                      Text('de $invitedBy · Rol: ${_roleLabel(role)}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (token != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _declineInvitation(context, data, inv),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.expenseColor),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _acceptInvitation(context, data, token),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Household card ──────────────────────────────────────────────

  Widget _buildHouseholdCard(BuildContext context, Map<String, dynamic> household, DataProvider data) {
    final id = household['id'] as int;
    final name = household['name'] as String? ?? 'Grupo';
    final role = household['role'] as String? ?? 'read';
    final memberCount = household['member_count'] as int? ?? 0;
    final members = household['members'] as List<dynamic>? ?? [];
    final pendingInvitations = (household['pending_invitations'] as List<dynamic>?) ?? [];
    final isDefault = data.defaultHouseholdId == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.group, color: AppTheme.primaryColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context))),
            ),
            if (isDefault)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: AppTheme.primaryColor),
                    SizedBox(width: 4),
                    Text('Predeterminado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text('${_roleLabel(role)} · $memberCount miembros',
            style: TextStyle(color: AppTheme.textSecondary(context))),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          // Members
          if (members.isEmpty)
            Text('Cargando miembros...', style: TextStyle(color: AppTheme.grey400(context)))
          else
            ...members.map((m) => _buildMemberTile(context, m, id, role, data)),

          // Pending invitations
          if (pendingInvitations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, size: 16, color: AppTheme.grey500(context)),
                const SizedBox(width: 6),
                Text(
                  'Invitaciones pendientes (${pendingInvitations.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...pendingInvitations.map((inv) => _buildHouseholdPendingInvitationTile(
                  context,
                  inv as Map<String, dynamic>,
                  id,
                  role,
                  data,
                )),
          ],

          const SizedBox(height: 12),

          // Action buttons (Default, Invite & Delete)
          Row(
            children: [
              if (!isDefault) ...[
                IconButton.outlined(
                  onPressed: () async {
                    await data.setDefaultHousehold(id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"$name" establecido como grupo predeterminado')),
                      );
                    }
                  },
                  icon: const Icon(Icons.star_outline, size: 20, color: AppTheme.primaryColor),
                  tooltip: 'Marcar como predeterminado',
                ),
                const SizedBox(width: 8),
              ],
              if (role == 'owner' || role == 'admin')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showInviteDialog(context, id),
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Invitar miembro'),
                  ),
                ),
              if (role == 'owner') ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _confirmDeleteHousehold(context, id, name, data),
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.expenseColor),
                  tooltip: 'Eliminar grupo',
                  style: IconButton.styleFrom(
                    side: BorderSide(color: AppTheme.expenseColor.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteHousehold(
      BuildContext context, int householdId, String name, DataProvider data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar grupo "$name"'),
        content: const Text(
          '¿Estás seguro de que querés eliminar este grupo?\n\n'
          'Solo se puede eliminar si no tiene transacciones ni ahorros asociados. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await data.deleteHousehold(householdId);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Grupo "$name" eliminado correctamente')),
                  );
                } else if (data.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(data.error!),
                      backgroundColor: AppTheme.expenseColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }


  Widget _buildMemberTile(BuildContext context, dynamic member, int householdId, String myRole, DataProvider data) {
    final m = member as Map<String, dynamic>;
    final memberId = m['id'] as int;
    final name = m['name'] as String? ?? 'Usuario';
    final memberRole = m['role'] as String? ?? 'read';
    final email = m['email'] as String? ?? '';
    final auth = context.read<AuthProvider>();
    final isMe = auth.userId == m['user_id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary(context))),
                if (email.isNotEmpty)
                  Text(email, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor(memberRole).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_roleLabel(memberRole),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _roleColor(memberRole))),
          ),
          // Role change (only if I'm owner/admin and target is not owner, and not me)
          if ((myRole == 'owner' || myRole == 'admin') && memberRole != 'owner' && !isMe)
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'remove') {
                  await data.removeMember(householdId, memberId);
                  await data.loadHouseholds();
                } else {
                  await data.updateMemberRole(householdId, memberId, action);
                }
              },
              itemBuilder: (_) => [
                if (memberRole != 'edit')
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                if (memberRole != 'read')
                  const PopupMenuItem(value: 'read', child: Text('Solo lectura')),
                if (myRole == 'owner' && memberRole != 'admin')
                  const PopupMenuItem(value: 'admin', child: Text('Admin')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'remove',
                  child: const Text('Eliminar', style: TextStyle(color: AppTheme.expenseColor)),
                ),
              ],
              icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary(context)),
            ),
        ],
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────

  void _showCreateHouseholdDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear grupo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre del grupo',
            hintText: 'Ej: Casa',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final data = context.read<DataProvider>();
              final success = await data.createHousehold(controller.text.trim());
              if (success && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, int householdId) {
    final emailController = TextEditingController();
    String selectedRole = 'read';
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invitar miembro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'correo@ejemplo.com',
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'read', child: Text('Solo lectura')),
                  DropdownMenuItem(value: 'edit', child: Text('Editar')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: isLoading
                    ? null
                    : (v) {
                        if (v != null) setDialogState(() => selectedRole = v);
                      },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: AppTheme.expenseColor, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) return;

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      final data = context.read<DataProvider>();
                      final response = await data.inviteMember(householdId, email, role: selectedRole);

                      if (response != null) {
                        if (ctx.mounted) Navigator.pop(ctx); // Close invite dialog
                        if (context.mounted) {
                          _showInvitationLinkDialog(context, response);
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = data.error ?? 'Error al enviar invitación';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Invitar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvitationLinkDialog(BuildContext context, Map<String, dynamic> invitation) {
    final link = invitation['invitation_link'] as String? ?? '';
    final email = invitation['invited_email'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Invitación Creada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se generó la invitación para $email.',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            const Text(
              'Copiá y compartí este enlace con tu familiar para que pueda unirse al grupo:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                link,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              if (ctx.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enlace de invitación copiado al portapapeles'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar enlace'),
          ),
        ],
      ),
    );
  }

  void _acceptInvitation(BuildContext context, DataProvider data, String token) async {
    final success = await data.acceptInvitation(token);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al aceptar invitación')),
      );
    }
  }

  void _declineInvitation(BuildContext context, DataProvider data, Map<String, dynamic> inv) {
    final id = inv['id'] as int?;
    if (id == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar invitación'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await data.declineInvitation(id);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdPendingInvitationTile(
    BuildContext context,
    Map<String, dynamic> inv,
    int householdId,
    String myRole,
    DataProvider data,
  ) {
    final invId = inv['id'] as int?;
    final email = inv['invited_email'] as String? ?? 'Invitación';
    final role = inv['role'] as String? ?? 'read';
    final expiresAtStr = inv['expires_at'] as String?;
    final token = inv['token'] as String? ?? '';
    final link = (inv['invitation_link'] as String?)?.isNotEmpty == true
        ? inv['invitation_link'] as String
        : '${Uri.base.origin}/invitar/$token';

    String expirationText = '';
    bool isExpired = false;
    if (expiresAtStr != null) {
      final exp = DateTime.tryParse(expiresAtStr)?.toLocal();
      if (exp != null) {
        final diff = exp.difference(DateTime.now());
        if (diff.isNegative) {
          expirationText = 'Expirada';
          isExpired = true;
        } else if (diff.inHours >= 1) {
          final hours = diff.inHours;
          final mins = diff.inMinutes % 60;
          expirationText = 'Expira en $hours hs${mins > 0 ? " $mins min" : ""}';
        } else {
          expirationText = 'Expira en ${diff.inMinutes} min';
        }
      }
    }

    final canManage = myRole == 'owner' || myRole == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpired
              ? AppTheme.expenseColor.withValues(alpha: 0.3)
              : Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: (isExpired ? AppTheme.expenseColor : Colors.amber)
                .withValues(alpha: 0.15),
            child: Icon(
              isExpired ? Icons.timer_off_outlined : Icons.schedule_outlined,
              size: 16,
              color: isExpired ? AppTheme.expenseColor : Colors.amber.shade800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _roleColor(role).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleLabel(role),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _roleColor(role),
                        ),
                      ),
                    ),
                  ],
                ),
                if (expirationText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    expirationText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isExpired
                          ? AppTheme.expenseColor
                          : (AppTheme.isDark(context)
                              ? Colors.amber.shade300
                              : Colors.amber.shade900),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Copy link action button
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copiar enlace de invitación',
            color: AppTheme.primaryColor,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Enlace copiado para $email'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
          // Cancel / Revoke button (only owner / admin)
          if (canManage && invId != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Cancelar invitación',
              color: AppTheme.expenseColor,
              onPressed: () => _confirmCancelHouseholdInvitation(context, invId, email, data),
            ),
        ],
      ),
    );
  }

  void _confirmCancelHouseholdInvitation(
    BuildContext context,
    int invitationId,
    String email,
    DataProvider data,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar invitación'),
        content: Text('¿Estás seguro de que querés revocar la invitación enviada a $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await data.declineInvitation(invitationId);
              if (context.mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invitación a $email cancelada')),
                );
              }
            },
            child: const Text('Cancelar invitación'),
          ),
        ],
      ),
    );
  }


  // ── Helpers ─────────────────────────────────────────────────────

  String _roleLabel(String role) {
    switch (role) {
      case 'owner': return 'Propietario';
      case 'admin': return 'Admin';
      case 'edit': return 'Editar';
      case 'read': return 'Solo lectura';
      default: return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner': return AppTheme.savingsColor;
      case 'admin': return AppTheme.primaryColor;
      case 'edit': return Colors.orange;
      case 'read': return AppTheme.textSecondary(context);
      default: return AppTheme.textSecondary(context);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textSecondary(context))),
    );
  }
}
