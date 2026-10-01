class CategoryBreakdown {
  final int id;
  final String name;
  final String? icon;
  final double total;
  final int count;

  CategoryBreakdown({
    required this.id,
    required this.name,
    this.icon,
    required this.total,
    this.count = 0,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      total: (json['total'] as num).toDouble(),
      count: json['count'] as int? ?? 0,
    );
  }
}

class UserBreakdown {
  final int id;
  final String name;
  final double total;

  UserBreakdown({
    required this.id,
    required this.name,
    required this.total,
  });

  factory UserBreakdown.fromJson(Map<String, dynamic> json) {
    return UserBreakdown(
      id: json['id'] as int,
      name: json['name'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }
}

class MonthlySummary {
  final int month;
  final int year;
  final double totalIncome;
  final double totalExpenses;
  final double fixedExpenses;
  final double variableExpenses;
  final double savings;
  final List<CategoryBreakdown> expensesByCategory;
  final List<CategoryBreakdown> incomeByCategory;
  final List<UserBreakdown> expensesByUser;
  final List<UserBreakdown> incomeByUser;

  MonthlySummary({
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalExpenses,
    required this.fixedExpenses,
    required this.variableExpenses,
    required this.savings,
    required this.expensesByCategory,
    required this.incomeByCategory,
    required this.expensesByUser,
    required this.incomeByUser,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      month: json['month'] as int,
      year: json['year'] as int,
      totalIncome: (json['total_income'] as num).toDouble(),
      totalExpenses: (json['total_expenses'] as num).toDouble(),
      fixedExpenses: (json['fixed_expenses'] as num).toDouble(),
      variableExpenses: (json['variable_expenses'] as num).toDouble(),
      savings: (json['savings'] as num).toDouble(),
      expensesByCategory: (json['expenses_by_category'] as List)
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      incomeByCategory: (json['income_by_category'] as List)
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      expensesByUser: (json['expenses_by_user'] as List)
          .map((e) => UserBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      incomeByUser: (json['income_by_user'] as List)
          .map((e) => UserBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
