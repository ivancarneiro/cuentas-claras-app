import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../config/currencies.dart';
import '../providers/data_provider.dart';
import '../models/monthly_summary.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, _) {
        final summary = data.monthlySummary;
        final currentMonth = summary?.month ?? data.selectedMonth;
        final currentYear = summary?.year ?? data.selectedYear;

        return RefreshIndicator(
          onRefresh: () => data.refreshAll(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Period selector (Always visible)
              _PeriodSelector(
                month: currentMonth,
                year: currentYear,
                onPrevious: () {
                  final m = currentMonth - 1;
                  data.setMonth(
                      m < 1 ? 12 : m, m < 1 ? currentYear - 1 : currentYear);
                },
                onNext: () {
                  final m = currentMonth + 1;
                  data.setMonth(
                      m > 12 ? 1 : m, m > 12 ? currentYear + 1 : currentYear);
                },
              ),
              const SizedBox(height: 16),

              if (data.isLoading && summary == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (summary == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note_outlined,
                            size: 48, color: AppTheme.grey400(context)),
                        const SizedBox(height: 12),
                        Text(
                          'Sin datos para este mes',
                          style:
                              TextStyle(color: AppTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => data.refreshAll(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Actualizar'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Balance card
                _BalanceCard(
                  income: summary.totalIncome,
                  expenses: summary.totalExpenses,
                  savings: summary.savings,
                ),
                const SizedBox(height: 16),

                // Breakdown by user
                if (summary.expensesByUser.isNotEmpty ||
                    summary.incomeByUser.isNotEmpty)
                  _UserBreakdownCard(summary: summary),
                const SizedBox(height: 16),

                // Expenses breakdown
                if (summary.expensesByCategory.isNotEmpty) ...[
                  _CategoryBreakdownCard(
                    title: 'Gastos por Categoría',
                    items: summary.expensesByCategory,
                    color: AppTheme.expenseColor,
                  ),
                  const SizedBox(height: 16),
                ],

                // Income breakdown
                if (summary.incomeByCategory.isNotEmpty)
                  _CategoryBreakdownCard(
                    title: 'Ingresos por Categoría',
                    items: summary.incomeByCategory,
                    color: AppTheme.incomeColor,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int month;
  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodSelector({
    required this.month,
    required this.year,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM', 'es').format(DateTime(2000, month));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Text(
          '${monthName[0].toUpperCase()}${monthName.substring(1)} $year',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double income;
  final double expenses;
  final double savings;

  const _BalanceCard({
    required this.income,
    required this.expenses,
    required this.savings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Donut chart
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: [
                    if (income > 0)
                      PieChartSectionData(
                        value: income,
                        color: AppTheme.incomeColor,
                        title: formatAmountCompact(income, 'ARS'),
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        radius: 60,
                      ),
                    if (expenses > 0)
                      PieChartSectionData(
                        value: expenses,
                        color: AppTheme.expenseColor,
                        title: formatAmountCompact(expenses, 'ARS'),
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        radius: 60,
                      ),
                    if (savings > 0)
                      PieChartSectionData(
                        value: savings,
                        color: AppTheme.savingsColor,
                        title: formatAmountCompact(savings, 'ARS'),
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        radius: 60,
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  centerSpaceColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem('Ingresos', AppTheme.incomeColor, income, context),
                _legendItem('Gastos', AppTheme.expenseColor, expenses, context),
                _legendItem('Ahorro', AppTheme.savingsColor, savings, context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, double amount, BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
          ],
        ),
        const SizedBox(height: 2),
        Text(formatAmount(amount, 'ARS'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary(context))),
      ],
    );
  }
}

class _UserBreakdownCard extends StatelessWidget {
  final MonthlySummary summary;
  const _UserBreakdownCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por Usuario', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 12),
            ...summary.incomeByUser.map((u) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: u.name == 'Ivan' ? Colors.blue.withValues(alpha: 0.1) : Colors.pink.withValues(alpha: 0.1),
                    child: Text(u.name[0], style: TextStyle(fontWeight: FontWeight.bold, color: u.name == 'Ivan' ? Colors.blue : Colors.pink)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(u.name, style: TextStyle(color: AppTheme.textPrimary(context)))),                    Text(formatAmount(u.total, 'ARS'), style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  final String title;
  final List<CategoryBreakdown> items;
  final Color color;

  const _CategoryBreakdownCard({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sortedItems = List<CategoryBreakdown>.from(items)
      ..sort((a, b) => b.total.compareTo(a.total));
    final total = sortedItems.fold<double>(0, (sum, i) => sum + i.total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 12),
            ...sortedItems.take(8).map((item) {
              final pct = total > 0 ? item.total / total * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.icon ?? ''} ${item.name}',
                            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatAmount(item.total, 'ARS'),
                          style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: color.withValues(alpha: 0.1),
                        color: color,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (sortedItems.length > 8)
              Text('+${sortedItems.length - 8} más',
                  style: TextStyle(color: AppTheme.grey500(context), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
