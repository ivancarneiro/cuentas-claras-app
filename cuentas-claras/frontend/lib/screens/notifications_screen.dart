import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';
import '../services/push_notification_service.dart';
import '../widgets/user_avatar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
      try {
        context.read<PushNotificationService>().requestPermissions();
      } catch (_) {}
    });
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Recién';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'transaction_created':
        return Icons.add_circle_outline_rounded;
      case 'transaction_updated':
        return Icons.edit_note_rounded;
      case 'transaction_deleted':
        return Icons.delete_outline_rounded;
      case 'member_joined':
        return Icons.person_add_alt_1_rounded;
      case 'invite_sent':
        return Icons.mail_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'transaction_created':
        return AppTheme.incomeColor;
      case 'transaction_updated':
        return Colors.orangeAccent;
      case 'transaction_deleted':
        return AppTheme.expenseColor;
      case 'member_joined':
      case 'invite_sent':
        return AppTheme.primaryColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final notifications = notifProvider.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notificaciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (notifProvider.unreadCount > 0)
              Text(
                '${notifProvider.unreadCount} sin leer',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Probar notificación en dispositivo',
            icon: const Icon(Icons.notification_add_outlined, size: 20),
            onPressed: () async {
              try {
                final pushService = context.read<PushNotificationService>();
                await pushService.requestPermissions();
                await pushService.showLocalNotification(
                  id: 99999,
                  title: '🔔 Cuentas Claras',
                  body: 'Las notificaciones del sistema están funcionando correctamente.',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notificación de prueba enviada'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),
          if (notifications.isNotEmpty && notifProvider.unreadCount > 0)
            TextButton.icon(
              onPressed: () => notifProvider.markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Leer todas', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifProvider.loadNotifications(refresh: true),
        child: notifProvider.isLoading && notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return _buildNotificationCard(context, item, notifProvider, isDark);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Todo al día',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Te avisaremos cuando haya nuevos movimientos o cambios en tus grupos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem item,
    NotificationProvider provider,
    bool isDark,
  ) {
    final typeColor = _getTypeColor(item.type);
    final typeIcon = _getTypeIcon(item.type);

    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.expenseColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      onDismissed: (_) {
        provider.deleteNotification(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notificación eliminada'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => provider.loadNotifications(refresh: true),
            ),
          ),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (!item.isRead) {
            provider.markAsRead(item.id);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? AppTheme.surface(context)
                : (isDark
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : const Color(0xFFEEF2FF)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead
                  ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))
                  : AppTheme.primaryColor.withValues(alpha: 0.35),
              width: item.isRead ? 1 : 1.5,
            ),
            boxShadow: item.isRead
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Actor avatar or icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    radius: 20,
                    name: item.actorShortName ?? item.actorName ?? 'Usuario',
                    photoUrl: item.actorPhotoUrl,
                    userId: item.actorId,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.surface(context),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(typeIcon, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatRelativeTime(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isRead
                                ? AppTheme.textSecondary(context)
                                : AppTheme.primaryColor,
                            fontWeight: item.isRead ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.isRead
                            ? AppTheme.textSecondary(context)
                            : (isDark ? Colors.white70 : Colors.black87),
                        height: 1.3,
                      ),
                    ),
                    if (item.householdName != null && item.householdName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.home_work_outlined,
                              size: 11,
                              color: AppTheme.textSecondary(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.householdName!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Unread indicator dot
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
