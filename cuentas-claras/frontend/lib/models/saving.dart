class SavingAccount {
  final int id;
  final String name;
  final String currency;
  final String? description;

  SavingAccount({
    required this.id,
    required this.name,
    this.currency = 'ARS',
    this.description,
  });

  factory SavingAccount.fromJson(Map<String, dynamic> json) {
    return SavingAccount(
      id: json['id'] as int,
      name: json['name'] as String,
      currency: json['currency'] as String? ?? 'ARS',
      description: json['description'] as String?,
    );
  }
}

class Saving {
  final int id;
  final int accountId;
  final String? accountName;
  final String? currency;
  final int? month;
  final int? year;
  final double balance;
  final double? balanceArs;
  final String? note;
  final double percentage;

  Saving({
    required this.id,
    required this.accountId,
    this.accountName,
    this.currency,
    this.month,
    this.year,
    required this.balance,
    this.balanceArs,
    this.note,
    this.percentage = 0.0,
  });

  factory Saving.fromJson(Map<String, dynamic> json) {
    return Saving(
      id: json['saving_id'] ?? json['id'] as int,
      accountId: (json['account_id'] ?? json['id']) as int,
      accountName: json['account_name'] as String?,
      currency: json['currency'] as String? ?? 'ARS',
      month: json['month'] as int?,
      year: json['year'] as int?,
      balance: ((json['balance'] ?? 0.0) as num).toDouble(),
      balanceArs: json['balance_ars'] != null ? (json['balance_ars'] as num).toDouble() : null,
      note: json['note'] as String?,
      percentage: ((json['percentage'] ?? 0.0) as num).toDouble(),
    );
  }
}

class MonthlyFlowItem {
  final int month;
  final String name;
  final double income;
  final double expenses;
  final double autoAmountArs;
  final double amountArs;
  final bool isManual;
  final String? note;
  final double percentage;

  MonthlyFlowItem({
    required this.month,
    required this.name,
    required this.income,
    required this.expenses,
    required this.autoAmountArs,
    required this.amountArs,
    this.isManual = false,
    this.note,
    required this.percentage,
  });

  factory MonthlyFlowItem.fromJson(Map<String, dynamic> json) {
    return MonthlyFlowItem(
      month: json['month'] as int,
      name: json['name'] as String,
      income: ((json['income'] ?? 0.0) as num).toDouble(),
      expenses: ((json['expenses'] ?? 0.0) as num).toDouble(),
      autoAmountArs: ((json['auto_amount_ars'] ?? json['amount_ars'] ?? 0.0) as num).toDouble(),
      amountArs: ((json['amount_ars'] ?? 0.0) as num).toDouble(),
      isManual: json['is_manual'] as bool? ?? false,
      note: json['note'] as String?,
      percentage: ((json['percentage'] ?? 0.0) as num).toDouble(),
    );
  }
}

class SavingsSummary {
  final List<Saving> accounts;
  final List<MonthlyFlowItem> monthlyFlow;
  final double totalArs;
  final double accountsTotalArs;
  final double monthsTotalArs;
  final double usdRate;
  final double totalUsd;
  final int year;

  SavingsSummary({
    required this.accounts,
    this.monthlyFlow = const [],
    required this.totalArs,
    this.accountsTotalArs = 0.0,
    this.monthsTotalArs = 0.0,
    this.usdRate = 1400.0,
    this.totalUsd = 0.0,
    this.year = 2026,
  });

  factory SavingsSummary.fromJson(Map<String, dynamic> json) {
    return SavingsSummary(
      accounts: (json['accounts'] as List? ?? [])
          .map((e) => Saving.fromJson(e as Map<String, dynamic>))
          .toList(),
      monthlyFlow: (json['monthly_flow'] as List? ?? [])
          .map((e) => MonthlyFlowItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalArs: ((json['total_ars'] ?? 0.0) as num).toDouble(),
      accountsTotalArs: ((json['accounts_total_ars'] ?? 0.0) as num).toDouble(),
      monthsTotalArs: ((json['months_total_ars'] ?? 0.0) as num).toDouble(),
      usdRate: ((json['usd_rate'] ?? 1400.0) as num).toDouble(),
      totalUsd: ((json['total_usd'] ?? 0.0) as num).toDouble(),
      year: json['year'] as int? ?? DateTime.now().year,
    );
  }
}
