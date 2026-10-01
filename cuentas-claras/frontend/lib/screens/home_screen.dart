import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/debug_overlay.dart';
import '../services/logger_service.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'savings_screen.dart';
import 'add_transaction_screen.dart';
import 'household_screen.dart';
import 'categories_screen.dart';
import 'profile_screen.dart';
import 'admin_users_screen.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardScreen(),
    TransactionsScreen(),
    SavingsScreen(),
    HouseholdScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final name = auth.userName;
    final photoUrl = auth.user?['photo_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
            const Text('Cuentas Claras', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          // Debug Logs
          Consumer<LoggerService>(
            builder: (context, logger, _) {
              final errorCount = logger.entries.where((e) => e.level == LogLevel.error).length;
              final warnCount = logger.entries.where((e) => e.level == LogLevel.warning).length;
              final color = errorCount > 0
                  ? Colors.red
                  : warnCount > 0
                      ? Colors.orange
                      : null;
              return IconButton(
                icon: Icon(Icons.bug_report_outlined, color: color),
                tooltip: 'Logs de depuración',
                onPressed: () {
                  DebugOverlay.showDebugPanel.value = !DebugOverlay.showDebugPanel.value;
                },
              );
            },
          ),
          // Categories
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Categorías',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              );
            },
          ),
          // Theme toggle
          IconButton(
            icon: Icon(themeProvider.icon),
            tooltip: 'Tema: ${themeProvider.label}',
            onPressed: () => themeProvider.toggleTheme(),
          ),
          // User avatar / menu
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 48),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) => setState(() {})); // Refresh UI after profile edit
                } else if (value == 'admin_users') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                  );
                } else if (value == 'logout') {
                  auth.logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Row(
                    children: [
                      UserAvatar(
                        radius: 18,
                        name: name,
                        photoUrl: photoUrl,
                        userId: auth.userId,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(auth.user?['email'] ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person_outline, size: 20),
                    title: Text('Mi Perfil'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (auth.user?['is_app_owner'] == true) ...[
                  const PopupMenuItem(
                    value: 'admin_users',
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings_outlined, size: 20, color: AppTheme.primaryColor),
                      title: Text('Administrar Usuarios'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'logout',
                  child: const ListTile(
                    leading: Icon(Icons.logout, size: 20, color: AppTheme.expenseColor),
                    title: Text('Cerrar sesión', style: TextStyle(color: AppTheme.expenseColor)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              child: UserAvatar(
                radius: 16,
                name: name,
                photoUrl: photoUrl,
                userId: auth.userId,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, _) {
          return Column(
            children: [
              if (data.households.isNotEmpty)
                _buildHouseholdSelectorBar(context, data),
              Expanded(child: _pages[_currentIndex]),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Resumen',
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: 'Movimientos',
                ),
                // Center Action Button (+)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: 'Nueva transacción',
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddTransactionScreen()),
                        ).then((changed) {
                          if (changed == true) {
                            context.read<DataProvider>().refreshAll();
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child:
                            const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
                _buildNavItem(
                  context: context,
                  index: 2,
                  icon: Icons.savings_outlined,
                  selectedIcon: Icons.savings,
                  label: 'Ahorros',
                ),
                Consumer<DataProvider>(
                  builder: (context, data, _) => _buildNavItem(
                    context: context,
                    index: 3,
                    icon: Icons.group_outlined,
                    selectedIcon: Icons.group,
                    label: 'Grupo',
                    badgeCount: data.pendingInvitations.length,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? AppTheme.primaryColor
        : (Theme.of(context).brightness == Brightness.light
            ? Colors.grey.shade600
            : Colors.grey.shade400);

    Widget iconWidget = Icon(
      isSelected ? selectedIcon : icon,
      color: color,
      size: 22,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        child: iconWidget,
      );
    }

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHouseholdSelectorBar(BuildContext context, DataProvider data) {
    final households = data.households;
    final selectedId = data.selectedHouseholdId;
    final currentH = households.firstWhere(
      (h) => h['id'] == selectedId,
      orElse: () => households.isNotEmpty ? households.first : {},
    );
    final name = currentH['name'] as String? ?? 'Sin grupo';
    final isDefault = currentH['id'] == data.defaultHouseholdId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showHouseholdPicker(context, data),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home_work_outlined, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (isDefault) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
          if (households.length > 1)
            Text(
              '${households.length} grupos',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
            ),
        ],
      ),
    );
  }

  void _showHouseholdPicker(BuildContext context, DataProvider data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Seleccionar Grupo Activo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _currentIndex = 3); // Go to Households tab
                        },
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('Gestionar', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ...data.households.map((h) {
                  final id = h['id'] as int;
                  final name = h['name'] as String? ?? 'Grupo';
                  final isSelected = id == data.selectedHouseholdId;
                  final isDefault = id == data.defaultHouseholdId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.group_outlined,
                        color: isSelected ? AppTheme.primaryColor : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppTheme.primaryColor : null,
                      ),
                    ),
                    subtitle: Text(
                      isDefault ? 'Grupo predeterminado (Default)' : 'Tocar para activar',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDefault ? Colors.amber[800] : AppTheme.textSecondary(context),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isDefault ? Icons.star_rounded : Icons.star_border_rounded,
                            color: isDefault ? Colors.amber : Colors.grey,
                          ),
                          tooltip: isDefault
                              ? 'Grupo predeterminado'
                              : 'Fijar como predeterminado',
                          onPressed: () async {
                            await data.setDefaultHousehold(id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20),
                      ],
                    ),
                    onTap: () {
                      data.setSelectedHousehold(id);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

