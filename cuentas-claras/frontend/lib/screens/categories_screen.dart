import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/data_provider.dart';
import '../models/category.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int? _householdFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nueva categoría',
            onPressed: () => _showCategoryForm(context, null),
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, _) {
          final allCats = data.categories;
          final households = data.households;

          // Default filter to active household if null
          final currentFilter = _householdFilter ??
              data.selectedHouseholdId ??
              (households.isNotEmpty ? households.first['id'] as int : null);

          final cats = currentFilter != null
              ? allCats
                  .where((c) =>
                      c.householdId == null || c.householdId == currentFilter)
                  .toList()
              : allCats;

          if (allCats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined,
                      size: 64, color: AppTheme.grey300(context)),
                  const SizedBox(height: 16),
                  Text('Sin categorías',
                      style: TextStyle(
                          color: AppTheme.grey500(context), fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Agregá categorías para clasificar tus transacciones',
                      style: TextStyle(color: AppTheme.grey400(context))),
                ],
              ),
            );
          }

          // Group by type
          final income = cats.where((c) => c.type == 'income').toList();
          final variableExpense =
              cats.where((c) => c.type == 'variable_expense').toList();
          final fixedExpense =
              cats.where((c) => c.type == 'fixed_expense').toList();

          return RefreshIndicator(
            onRefresh: () => data.loadCategories(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Household Filter dropdown if multiple households
                if (households.length > 1) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),

                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: currentFilter,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: [
                          ...households.map((h) => DropdownMenuItem<int?>(
                                value: h['id'] as int,
                                child: Row(
                                  children: [
                                    const Icon(Icons.group,
                                        size: 18, color: AppTheme.primaryColor),
                                    const SizedBox(width: 8),
                                    Text('Grupo: ${h['name']}'),
                                  ],
                                ),
                              )),
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.all_inclusive,
                                    size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Todos los grupos'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _householdFilter = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (income.isNotEmpty) ...[
                  const _SectionHeader(title: 'Ingresos'),
                  ...income.map((c) => _CategoryTile(
                        category: c,
                        showHousehold: currentFilter == null,
                        onEdit: (cat) => _showCategoryForm(context, cat),
                        onDelete: (cat) => _confirmDelete(context, data, cat),
                      )),
                  const SizedBox(height: 16),
                ],
                if (variableExpense.isNotEmpty) ...[
                  const _SectionHeader(title: 'Gastos variables'),
                  ...variableExpense.map((c) => _CategoryTile(
                        category: c,
                        showHousehold: currentFilter == null,
                        onEdit: (cat) => _showCategoryForm(context, cat),
                        onDelete: (cat) => _confirmDelete(context, data, cat),
                      )),
                  const SizedBox(height: 16),
                ],
                if (fixedExpense.isNotEmpty) ...[
                  const _SectionHeader(title: 'Gastos fijos'),
                  ...fixedExpense.map((c) => _CategoryTile(
                        category: c,
                        showHousehold: currentFilter == null,
                        onEdit: (cat) => _showCategoryForm(context, cat),
                        onDelete: (cat) => _confirmDelete(context, data, cat),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCategoryForm(BuildContext context, Category? category) {
    final isEditing = category != null;
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: isEditing ? category.name : '');
    String type = isEditing ? category.type : 'variable_expense';
    final iconController =
        TextEditingController(text: isEditing ? (category.icon ?? '') : '');

    final data = context.read<DataProvider>();
    int? selectedHouseholdId = isEditing
        ? category.householdId
        : (_householdFilter ??
            data.selectedHouseholdId ??
            (data.households.isNotEmpty
                ? data.households.first['id'] as int
                : null));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar categoría' : 'Nueva categoría'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                      DropdownMenuItem(
                          value: 'variable_expense',
                          child: Text('Gasto variable')),
                      DropdownMenuItem(
                          value: 'fixed_expense', child: Text('Gasto fijo')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
                  ),
                  if (data.households.length > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: selectedHouseholdId,
                      decoration: const InputDecoration(
                        labelText: 'Grupo familiar',
                        prefixIcon: Icon(Icons.group_outlined),
                      ),
                      items: data.households
                          .map((h) => DropdownMenuItem<int?>(
                                value: h['id'] as int,
                                child: Text(h['name'] as String? ?? 'Grupo'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedHouseholdId = v);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'Icono (opcional)',
                      hintText: 'Ej: 🏠 💡 🚗 🍎',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final payload = {
                  'name': nameController.text.trim(),
                  'type': type,
                  'household_id': selectedHouseholdId,
                  'icon': iconController.text.trim(),
                };
                final success = isEditing
                    ? await data.updateCategory(category.id, payload)
                    : (await data.createCategory(payload) != null);
                if (success && ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),

            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, DataProvider data, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
            '¿Eliminar "${category.name}"? Las transacciones existentes conservarán su historial.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              data.deleteCategory(category.id);
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.expenseColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textSecondary(context))),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool showHousehold;
  final void Function(Category) onEdit;
  final void Function(Category) onDelete;

  const _CategoryTile({
    required this.category,
    this.showHousehold = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = category.type == 'variable_expense' ||
        category.type == 'fixed_expense';
    final color = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

    final subtitle = [
      _typeLabel(category.type),
      if (showHousehold && category.householdName != null)
        category.householdName!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              category.icon ?? (isExpense ? '💳' : '💰'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        title: Text(category.name,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary(context))),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary(context))),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit(category);
            } else if (value == 'delete') {
              onDelete(category);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Eliminar',
                  style: TextStyle(color: AppTheme.expenseColor)),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'income':
        return 'Ingreso';
      case 'variable_expense':
        return 'Gasto variable';
      case 'fixed_expense':
        return 'Gasto fijo';
      default:
        return type;
    }
  }
}

