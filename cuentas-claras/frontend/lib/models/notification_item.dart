class NotificationItem {
  final int id;
  final int userId;
  final int? actorId;
  final String? actorName;
  final String? actorShortName;
  final String? actorPhotoUrl;
  final int? householdId;
  final String? householdName;
  final String title;
  final String message;
  final String type;
  final int? referenceId;
  bool isRead;
  final DateTime? createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    this.actorId,
    this.actorName,
    this.actorShortName,
    this.actorPhotoUrl,
    this.householdId,
    this.householdName,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    required this.isRead,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['created_at'] != null) {
      dt = DateTime.tryParse(json['created_at'].toString())?.toLocal();
    }
    return NotificationItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      actorId: json['actor_id'] as int?,
      actorName: json['actor_name'] as String?,
      actorShortName: json['actor_short_name'] as String?,
      actorPhotoUrl: json['actor_photo_url'] as String?,
      householdId: json['household_id'] as int?,
      householdName: json['household_name'] as String?,
      title: json['title'] as String? ?? 'Notificación',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      referenceId: json['reference_id'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: dt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'actor_id': actorId,
    'actor_name': actorName,
    'actor_short_name': actorShortName,
    'actor_photo_url': actorPhotoUrl,
    'household_id': householdId,
    'household_name': householdName,
    'title': title,
    'message': message,
    'type': type,
    'reference_id': referenceId,
    'is_read': isRead,
    'created_at': createdAt?.toIso8601String(),
  };
}
