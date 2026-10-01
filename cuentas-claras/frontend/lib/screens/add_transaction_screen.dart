import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../config/currencies.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction; // If set, we're editing

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'expense';
  int? _selectedHouseholdId;
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isFixed = false;
  bool _isSaving = false;
  String _currency = 'ARS';

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final tx = widget.transaction!;
      _type = tx.type;
      _currency = tx.currency;
      _selectedDate = DateTime.tryParse(tx.date) ?? DateTime.now();
      _isFixed = tx.isFixed;
      _selectedHouseholdId = tx.householdId;
      _amountController.text = tx.amount.toString();
      _descriptionController.text = tx.description ?? '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = context.read<DataProvider>();
    if (_selectedHouseholdId == null) {
      _selectedHouseholdId = data.selectedHouseholdId ??
          (data.households.isNotEmpty ? data.households.first['id'] as int : null);
    }
    if (_isEditing && _selectedCategory == null) {
      _selectedCategory = data.categories.cast<Category?>().firstWhere(
        (c) => c!.id == widget.transaction!.categoryId,
        orElse: () => null,
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una categoría')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final data = context.read<DataProvider>();
    final auth = context.read<AuthProvider>();

    final payload = {
      'user_id': auth.userId,
      'household_id': _selectedHouseholdId,
      'category_id': _selectedCategory!.id,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'description': _descriptionController.text.trim(),
      'amount': double.parse(_amountController.text.replaceAll(',', '.')),
      'currency': _currency,
      'type': _type,
      'is_fixed': _isFixed,
    };

    final success = _isEditing
        ? await data.updateTransaction(widget.transaction!.id, payload)
        : await data.addTransaction(payload);

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context, true); // true = changed
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar transacción' : 'Nueva transacción')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Gasto',
                      icon: Icons.arrow_downward,
                      isSelected: _type == 'expense',
                      color: AppTheme.expenseColor,
                      onTap: () => setState(() => _type = 'expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeButton(
                      label: 'Ingreso',
                      icon: Icons.arrow_upward,
                      isSelected: _type == 'income',
                      color: AppTheme.incomeColor,
                      onTap: () => setState(() => _type = 'income'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Household / Grupo selector
              Consumer<DataProvider>(
                builder: (context, data, _) {
                  if (data.households.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<int>(
                      value: _selectedHouseholdId != null &&
                              data.households
                                  .any((h) => h['id'] == _selectedHouseholdId)
                          ? _selectedHouseholdId
                          : (data.households.isNotEmpty
                              ? data.households.first['id'] as int
                              : null),
                      decoration: const InputDecoration(
                        labelText: 'Grupo familiar',
                        prefixIcon: Icon(Icons.group_outlined),
                      ),
                      items: data.households.map<DropdownMenuItem<int>>((h) {
                        final id = h['id'] as int;
                        final name = h['name'] as String? ?? 'Grupo';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedHouseholdId = v;
                            if (_selectedCategory != null &&
                                _selectedCategory!.householdId != null &&
                                _selectedCategory!.householdId != v) {
                              _selectedCategory = null;
                            }
                          });
                        }
                      },
                    ),
                  );
                },
              ),

              // Amount + Currency row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresá un monto';
                        final parsed =
                            double.tryParse(v.replaceAll(',', '.'));
                        if (parsed == null || parsed <= 0)
                          return 'Monto inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: currencyDropdownItems(),
                      onChanged: (v) {
                        if (v != null) setState(() => _currency = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category with Quick Add button
              Consumer<DataProvider>(
                builder: (context, data, _) {
                  final allCats = _type == 'expense'
                      ? [
                          ...data.fixedExpenseCategories,
                          ...data.variableExpenseCategories
                        ]
                      : data.incomeCategories;
                  final cats = _selectedHouseholdId != null
                      ? allCats
                          .where((c) =>
                              c.householdId == null ||
                              c.householdId == _selectedHouseholdId)
                          .toList()
                      : allCats;

                  final currentCat = (cats.contains(_selectedCategory))
                      ? _selectedCategory
                      : null;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Category>(
                          value: currentCat,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: cats
                              .map<DropdownMenuItem<Category>>((cat) =>
                                  DropdownMenuItem<Category>(
                                    value: cat,
                                    child: Text(
                                        '${cat.icon ?? ''} ${cat.name}'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        tooltip: 'Crear nueva categoría',
                        onPressed: () =>
                            _showQuickAddCategoryDialog(context, data),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),



              // Date
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    locale: const Locale('es', 'AR'),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Fixed expense toggle
              if (_type == 'expense')
                SwitchListTile(
                  title: const Text('Gasto fijo'),
                  subtitle: const Text('Se repite todos los meses'),
                  value: _isFixed,
                  onChanged: (v) => setState(() => _isFixed = v),
                  contentPadding: EdgeInsets.zero,
                ),

              const SizedBox(height: 24),

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
                      : Text(_isEditing ? 'Guardar cambios' : 'Guardar',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickAddCategoryDialog(BuildContext context, DataProvider data) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final iconController = TextEditingController();
    String categoryType = _type == 'expense'
        ? (_isFixed ? 'fixed_expense' : 'variable_expense')
        : 'income';
    int? categoryHouseholdId = _selectedHouseholdId ??
        data.selectedHouseholdId ??
        (data.households.isNotEmpty
            ? data.households.first['id'] as int
            : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nueva categoría'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la categoría',
                      hintText: 'Ej: Mascotas, Alquiler, Gimnasio',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresá un nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoryType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                      DropdownMenuItem(
                          value: 'variable_expense', child: Text('Gasto variable')),
                      DropdownMenuItem(
                          value: 'fixed_expense', child: Text('Gasto fijo')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => categoryType = v);
                    },
                  ),
                  if (data.households.length > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: categoryHouseholdId,
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
                          setDialogState(() => categoryHouseholdId = v);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'Icono / Emoji (opcional)',
                      hintText: 'Ej: 🏠 💡 🚗 🍎 🐾',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final payload = {
                  'name': nameController.text.trim(),
                  'type': categoryType,
                  'household_id': categoryHouseholdId,
                  'icon': iconController.text.trim(),
                };
                final newCat = await data.createCategory(payload);
                if (newCat != null && ctx.mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    if (categoryHouseholdId != null) {
                      _selectedHouseholdId = categoryHouseholdId;
                    }
                    if (categoryType == 'income') {
                      _type = 'income';
                    } else {
                      _type = 'expense';
                      _isFixed = categoryType == 'fixed_expense';
                    }
                    _selectedCategory = newCat;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Categoría "${newCat.name}" creada y seleccionada'),
                    ),
                  );
                }
              },
              child: const Text('Crear y usar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.chipBg(context),
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textSecondary(context), size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? color : AppTheme.textSecondary(context),
            )),
          ],
        ),
      ),
    );
  }
}
