class User {
  final int id;
  final String name;
  final String email;
  final String? shortName;
  final String? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.shortName,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      shortName: json['short_name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'short_name': shortName,
    'created_at': createdAt,
  };
}
