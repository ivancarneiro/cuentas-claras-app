import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/currencies.dart';
import '../providers/data_provider.dart';
import '../models/transaction.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _showIncome = true;
  bool _showExpense = true;
  String? _currencyFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _filtered(List<Transaction> all) {
    return all.where((tx) {
      if (tx.type == 'income' && !_showIncome) return false;
      if (tx.type == 'expense' && !_showExpense) return false;
      if (_currencyFilter != null && tx.currency != _currencyFilter) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final desc = (tx.description ?? '').toLowerCase();
        final cat = (tx.categoryName ?? '').toLowerCase();
        final user = (tx.userName ?? '').toLowerCase();
        final h = (tx.householdName ?? '').toLowerCase();
        if (!desc.contains(q) && !cat.contains(q) && !user.contains(q) && !h.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, _) {
        if (data.isLoading && data.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = _filtered(data.transactions);

        return RefreshIndicator(
          onRefresh: () => data.refreshAll(),
          child: Column(
            children: [
              // Filters & Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.filterBarBg(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Input
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.chipBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.grey300(context).withValues(alpha: 0.5),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Buscar movimiento por descripción, categoría...',
                          hintStyle: TextStyle(fontSize: 12, color: AppTheme.grey400(context)),
                          prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.grey400(context)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Filter Chips and Currency (scrollable horizontal if needed to never overflow)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Ingresos',
                            icon: Icons.arrow_upward,
                            color: AppTheme.incomeColor,
                            selected: _showIncome,
                            onTap: () => setState(() => _showIncome = !_showIncome),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Gastos',
                            icon: Icons.arrow_downward,
                            color: AppTheme.expenseColor,
                            selected: _showExpense,
                            onTap: () => setState(() => _showExpense = !_showExpense),
                          ),
                          const SizedBox(width: 8),
                          // Currency filter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.chipBg(context),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _currencyFilter,
                                icon: const Icon(Icons.currency_exchange, size: 15),
                                iconSize: 16,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary(context),
                                ),
                                dropdownColor: AppTheme.filterBarBg(context),
                                selectedItemBuilder: (context) {
                                  return [
                                    Center(child: Text('Todas', style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12))),
                                    ...supportedCurrencies.map((c) => Center(
                                      child: Text(c.code, style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                                    )),
                                  ];
                                },
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todas', style: TextStyle(color: AppTheme.textSecondary(context))),
                                  ),
                                  ...currencyDropdownItems(),
                                ],
                                onChanged: (v) => setState(() => _currencyFilter = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Active filter badge
                    if (_currencyFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Chip(
                          label: Text('Moneda: ${getCurrencyInfo(_currencyFilter).symbol} $_currencyFilter',
                              style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _currencyFilter = null),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        ),
                      ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.grey300(context)),
                            const SizedBox(height: 16),
                            Text(filtered.length != data.transactions.length
                                ? 'Sin resultados con los filtros actuales'
                                : 'Sin transacciones',
                                style: TextStyle(color: AppTheme.grey500(context), fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Agregá tu primer gasto o ingreso',
                                style: TextStyle(color: AppTheme.grey400(context))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          return _TransactionCard(
                            transaction: tx,
                            onTap: () => _openEdit(context, tx),
                            onDelete: () => _confirmDelete(context, data, tx),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, Transaction tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(transaction: tx),
      ),
    ).then((changed) {
      if (changed == true) {
        context.read<DataProvider>().refreshAll();
      }
    });
  }

  void _confirmDelete(BuildContext context, DataProvider data, Transaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('Eliminar "${tx.description ?? tx.categoryName}" de ${formatAmount(tx.amount, tx.currency)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              data.deleteTransaction(tx.id);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppTheme.chipBg(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppTheme.textSecondary(context)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 13, color: selected ? color : AppTheme.textSecondary(context))),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TransactionCard({
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final color = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;
    final date = transaction.date.length >= 10
        ? '${transaction.date.substring(8, 10)}/${transaction.date.substring(5, 7)}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isExpense ? Icons.shopping_bag_outlined : Icons.attach_money,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description ?? transaction.categoryName ?? '',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textPrimary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(date, style: TextStyle(fontSize: 12, color: AppTheme.grey500(context))),
                        if (transaction.categoryName != null && transaction.categoryName!.isNotEmpty)
                          Text(
                            transaction.categoryName!,
                            style: TextStyle(fontSize: 12, color: AppTheme.grey400(context)),
                          ),
                        if (transaction.householdName != null && transaction.householdName!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              transaction.householdName!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        if (transaction.currency != 'ARS')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.chipBg(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              transaction.currency,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isExpense ? '-' : '+'}${formatAmount(transaction.amount, transaction.currency)}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14),
                  ),
                  if (transaction.userName != null && transaction.userName!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      transaction.userName!,
                      style: TextStyle(fontSize: 11, color: AppTheme.grey400(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              // Delete
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: AppTheme.grey400(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
