class Notification {
  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type, // 'group_created', 'contribution_due', 'payout_received', etc.
    required this.groupId,
    required this.isRead,
    required this.createdAt,
    this.details,
  });

  final int id;
  final int userId;
  final String title;
  final String message;
  final String type;
  final int? groupId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? details;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'group_id': groupId,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'details': details != null ? mapToJsonString(details!) : null,
    };
  }

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      title: map['title'] as String,
      message: map['message'] as String,
      type: map['type'] as String,
      groupId: map['group_id'] as int?,
      isRead: (map['is_read'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      details: map['details'] != null
          ? jsonStringToMap(map['details'] as String)
          : null,
    );
  }

  static String mapToJsonString(Map<String, dynamic> map) {
    // Simple JSON serialization
    final pairs = <String>[];
    map.forEach((key, value) {
      pairs.add('"$key":"$value"');
    });
    return '{${pairs.join(',')}}';
  }

  static Map<String, dynamic> jsonStringToMap(String json) {
    // Simple JSON deserialization
    final map = <String, dynamic>{};
    final content = json.substring(1, json.length - 1);
    if (content.isEmpty) return map;

    final pairs = content.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].replaceAll('"', '').trim();
        final value = parts[1].replaceAll('"', '').trim();
        map[key] = value;
      }
    }
    return map;
  }
}