import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../config/currencies.dart';
import '../providers/data_provider.dart';
import '../models/saving.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'AR$',
    decimalDigits: 2,
  );

  String _formatArs(double amount) {
    return _currencyFormat.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, _) {
        if (data.isLoading && data.savingsSummary == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = data.savingsSummary;
        final accounts = summary?.accounts ?? [];
        final monthlyFlow = summary?.monthlyFlow ?? [];
        final totalArs = summary?.totalArs ?? 0.0;
        final totalUsd = summary?.totalUsd ?? 0.0;
        final year = summary?.year ?? DateTime.now().year;
        final totalYearFlow = monthlyFlow.fold<double>(0.0, (sum, i) => sum + i.amountArs);

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => data.refreshAll(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Tarjeta Principal: TOTAL AHORROS ──────────────────
                _buildHeroTotalCard(
                  context,
                  totalArs,
                  totalUsd,
                  accounts.length + (totalYearFlow != 0 ? 1 : 0),
                ),
                const SizedBox(height: 24),

                // ── Sección 1: Activos y Conceptos ─────────────────────
                _buildSectionHeader(
                  context,
                  title: 'Activos y Conceptos',
                  subtitle: 'Composición detallada del Total de Ahorros',
                  actionLabel: 'Nuevo Concepto',
                  onAction: () => _showAccountForm(context, null),
                ),
                const SizedBox(height: 12),
                if (accounts.isEmpty && totalYearFlow == 0)
                  _buildEmptyCard(
                    context,
                    title: 'Sin activos registrados',
                    subtitle: 'Agregá tus divisas o cuentas para ver su valor en AR\$',
                    buttonText: 'Agregar primer concepto',
                    onTap: () => _showAccountForm(context, null),
                  )
                else ...[
                  ...accounts.map((acc) => _buildAssetCard(context, acc, data, totalArs)),
                  // Concepto automático: Ahorro Mensual del Año
                  _buildMonthlySavingsConceptCard(
                    context,
                    totalYearFlow: totalYearFlow,
                    totalArs: totalArs,
                    year: year,
                  ),
                ],

                const SizedBox(height: 28),

                // ── Sección 2: Ahorro Mensual del Año ─────────────────
                _buildSectionHeader(
                  context,
                  title: 'Ahorro Mensual $year',
                  subtitle: 'Flujo de ingresos menos gastos mes a mes',
                  trailing: monthlyFlow.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(right: 37),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'TOTAL ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                              Text(
                                _formatArs(totalYearFlow),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: totalYearFlow >= 0
                                      ? AppTheme.savingsColor
                                      : AppTheme.expenseColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                _buildMonthlyFlowCard(context, monthlyFlow, totalArs, year, data),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tarjeta Hero: TOTAL AHORROS ─────────────────────────────────

  Widget _buildHeroTotalCard(
      BuildContext context, double totalArs, double totalUsd, int count) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.savingsColor.withValues(alpha: 0.15),
            AppTheme.savingsColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.savingsColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.savingsColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.savings_rounded,
                      color: AppTheme.savingsColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TOTAL AHORROS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppTheme.savingsColor,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showAccountForm(context, null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.savingsColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatArs(totalArs),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.savingsColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '≈ u\$d ${NumberFormat('#,##0.00', 'es_AR').format(totalUsd)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.grey400(context),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count conceptos activos',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.grey500(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header de Sección ───────────────────────────────────────────

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (trailing != null)
          trailing
        else if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 16),
            label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
      ],
    );
  }

  // ── Tarjeta de Activo / Divisa ──────────────────────────────────

  Widget _buildAssetCard(
      BuildContext context, Saving acc, DataProvider data, double totalArs) {
    final info = getCurrencyInfo(acc.currency ?? 'ARS');
    final isArs = (acc.currency ?? 'ARS').toUpperCase() == 'ARS';
    final balanceArs = acc.balanceArs ?? acc.balance;
    final pct = acc.percentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey300(context).withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAccountForm(context, acc),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icono de moneda
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      info.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: info.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Concepto y monto original
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.accountName ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (!isArs)
                        Text(
                          '${info.symbol} ${NumberFormat('#,##0.00', 'es_AR').format(acc.balance)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (acc.note != null && acc.note!.isNotEmpty)
                        Text(
                          acc.note!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey500(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Valor en ARS y Porcentaje
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatArs(balanceArs),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 4),
                // Menú de opciones
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: AppTheme.grey400(context)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAccountForm(context, acc);
                    } else if (val == 'delete') {
                      _confirmDelete(context, data, acc);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppTheme.expenseColor),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: AppTheme.expenseColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tarjeta de Concepto Automático: Ahorro Mensual del Año ──────

  Widget _buildMonthlySavingsConceptCard(
    BuildContext context, {
    required double totalYearFlow,
    required double totalArs,
    required int year,
    VoidCallback? onTap,
  }) {
    final pct = totalArs > 0 ? (totalYearFlow / totalArs) * 100 : 0.0;
    final isPositive = totalYearFlow >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.savingsColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icono representativo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.savingsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_graph_rounded,
                      color: AppTheme.savingsColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Título y badge automático
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Ahorro Mensual $year',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.savingsColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Auto',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.savingsColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Flujo acumulado ingresos - gastos',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Valor en AR$ y Porcentaje
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatArs(totalYearFlow),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isPositive
                            ? AppTheme.savingsColor
                            : AppTheme.expenseColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Grilla de Flujo Mensual (ENE a DIC) ──────────────────────────

  Widget _buildMonthlyFlowCard(
      BuildContext context, List<MonthlyFlowItem> flow, double totalArs, int year, DataProvider data) {
    if (flow.isEmpty) {
      return _buildEmptyCard(
        context,
        title: 'Sin movimientos mensuales',
        subtitle: 'Cargá transacciones en el año para ver el ahorro de cada mes',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.grey300(context).withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: flow.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: AppTheme.grey300(context).withValues(alpha: 0.3),
            indent: 16,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final item = flow[index];
            final isPositive = item.amountArs > 0;
            final isNegative = item.amountArs < 0;
            final color = isPositive
                ? AppTheme.savingsColor
                : (isNegative ? AppTheme.expenseColor : AppTheme.grey400(context));
            final sign = isPositive ? '+' : '';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showEditMonthlyFlowDialog(context, item, year, data),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Mes (ENE, FEB, ...)
                      Container(
                        width: 44,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Ingresos y Gastos subtítulo + Badge Manual
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Ing: ${_formatArs(item.income)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.incomeColor.withValues(alpha: 0.9),
                                  ),
                                ),
                                Text(
                                  'Gtos: ${_formatArs(item.expenses)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.expenseColor.withValues(alpha: 0.9),
                                  ),
                                ),
                                if (item.isManual)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Ajustado',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (item.note != null && item.note!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.note!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.grey500(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Monto Neto en ARS y Porcentaje + Icono editar
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$sign${_formatArs(item.amountArs)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.percentage >= 0 ? '+' : ''}${item.percentage.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: color.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: AppTheme.grey400(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Diálogo de Edición Manual de Ahorro Mensual ─────────────────

  void _showEditMonthlyFlowDialog(
      BuildContext context, MonthlyFlowItem item, int year, DataProvider data) {
    final controller = TextEditingController(
      text: item.amountArs.toStringAsFixed(2),
    );
    final noteController = TextEditingController(text: item.note ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.savingsColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.name} $year',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.savingsColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ajustar Ahorro Real',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.chipBg(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cálculo automático por transacciones:',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatArs(item.autoAmountArs),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: item.autoAmountArs >= 0 ? AppTheme.savingsColor : AppTheme.expenseColor,
                      ),
                    ),
                    Text(
                      '(Ingresos: ${_formatArs(item.income)} - Gastos: ${_formatArs(item.expenses)})',
                      style: TextStyle(fontSize: 10, color: AppTheme.grey500(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Monto Real en Pesos (AR\$)',
                  hintText: 'Ej: 757271.64 o -83199.55',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Motivo o Nota (opcional)',
                  hintText: 'Ej: Gastos no anotados / Efectivo',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (item.isManual)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await data.deleteMonthlyFlow(year, item.month);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ajuste de ${item.name} restablecido a cálculo automático')),
                  );
                }
              },
              child: const Text('Restablecer automático', style: TextStyle(color: AppTheme.expenseColor, fontSize: 12)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val == null) return;
              Navigator.pop(ctx);
              final success = await data.setMonthlyFlow(
                year,
                item.month,
                val,
                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ahorro de ${item.name} $year actualizado'),
                    backgroundColor: AppTheme.savingsColor,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Empty State Card ────────────────────────────────────────────

  Widget _buildEmptyCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey300(context).withValues(alpha: 0.6)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.savings_outlined, size: 48, color: AppTheme.grey300(context)),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.grey500(context)),
            ),
            if (buttonText != null && onTap != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Modal Form: Crear o Editar Cuenta/Activo ─────────────────────

  void _showAccountForm(BuildContext context, Saving? saving) {
    final isEditing = saving != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: isEditing ? saving.accountName : '');
    final origAmountController = TextEditingController(
      text: isEditing ? saving.balance.toStringAsFixed(2) : '',
    );
    final arsAmountController = TextEditingController(
      text: isEditing ? (saving.balanceArs ?? saving.balance).toStringAsFixed(2) : '',
    );
    String selectedCurrency = isEditing ? (saving.currency ?? 'ARS') : 'ARS';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isArs = selectedCurrency == 'ARS';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditing ? 'Editar Activo / Divisa' : 'Nuevo Activo / Divisa',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Concepto
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Concepto',
                          hintText: 'Ej: Dolar USA en billetera NaranjaX',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un concepto' : null,
                      ),
                      const SizedBox(height: 14),

                      // Moneda
                      DropdownButtonFormField<String>(
                        value: selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Moneda',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        items: currencyDropdownItems(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              selectedCurrency = val;
                              if (val == 'ARS') {
                                arsAmountController.text = origAmountController.text;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Monto original
                      TextFormField(
                        controller: origAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isArs ? 'Monto en Pesos AR\$' : 'Monto en $selectedCurrency',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        onChanged: (val) {
                          if (isArs) {
                            arsAmountController.text = val;
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresá el monto';
                          if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Monto inválido';
                          return null;
                        },
                      ),

                      // Si no es ARS: Monto en ARS
                      if (!isArs) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: arsAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Equivalente en Pesos AR\$',
                            hintText: 'Ej: 2485918.27',
                            prefixIcon: Icon(Icons.currency_exchange),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresá el valor en AR\$';
                            if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Monto inválido';
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Botón Guardar
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final data = context.read<DataProvider>();

                            final origAmount = double.parse(
                              origAmountController.text.replaceAll(',', '.'),
                            );
                            final arsAmount = isArs
                                ? origAmount
                                : double.parse(arsAmountController.text.replaceAll(',', '.'));

                            final payload = {
                              'name': nameController.text.trim(),
                              'currency': selectedCurrency,
                              'balance': origAmount,
                              'balance_ars': arsAmount,
                            };

                            bool success;
                            if (isEditing) {
                              success = await data.updateSavingAccount(saving.accountId, payload);
                            } else {
                              success = await data.createSavingAccount(payload);
                            }

                            if (success && ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing
                                      ? 'Concepto actualizado'
                                      : 'Concepto agregado con éxito'),
                                  backgroundColor: AppTheme.savingsColor,
                                ),
                              );
                            }
                          },
                          child: Text(
                            isEditing ? 'Guardar Cambios' : 'Agregar Concepto',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Confirmar Eliminación ────────────────────────────────────────

  void _confirmDelete(BuildContext context, DataProvider data, Saving acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar "${acc.accountName}"'),
        content: const Text(
          '¿Estás seguro de que querés eliminar este concepto de ahorro?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await data.deleteSavingAccount(acc.accountId);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Concepto eliminado correctamente')),
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
