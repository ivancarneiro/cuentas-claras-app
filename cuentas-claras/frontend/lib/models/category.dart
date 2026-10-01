class Category {
  final int id;
  final String name;
  final String type; // income, fixed_expense, variable_expense, savings
  final String? icon;
  final int? userId;
  final int? householdId;
  final String? householdName;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.userId,
    this.householdId,
    this.householdName,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String?,
      userId: json['user_id'] as int?,
      householdId: json['household_id'] as int?,
      householdName: json['household_name'] as String?,
      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'icon': icon,
    'user_id': userId,
    'household_id': householdId,
    'sort_order': sortOrder,
  };
}


