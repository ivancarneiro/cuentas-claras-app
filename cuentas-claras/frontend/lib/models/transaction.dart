class Transaction {
  final int id;
  final int userId;
  final String? userName;
  final int? householdId;
  final String? householdName;
  final int categoryId;
  final String? categoryName;
  final String? categoryType;
  final String date;
  final String? description;
  final double amount;
  final String currency;
  final String type; // income | expense
  final bool isFixed;

  Transaction({
    required this.id,
    required this.userId,
    this.userName,
    this.householdId,
    this.householdName,
    required this.categoryId,
    this.categoryName,
    this.categoryType,
    required this.date,
    this.description,
    required this.amount,
    this.currency = 'ARS',
    required this.type,
    this.isFixed = false,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String?,
      householdId: json['household_id'] as int?,
      householdName: json['household_name'] as String?,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String?,
      categoryType: json['category_type'] as String?,
      date: json['date'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'ARS',
      type: json['type'] as String,
      isFixed: json['is_fixed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'household_id': householdId,
    'category_id': categoryId,
    'date': date,
    'description': description,
    'amount': amount,
    'currency': currency,
    'type': type,
    'is_fixed': isFixed,
  };
}

