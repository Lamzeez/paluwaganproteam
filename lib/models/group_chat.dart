class GroupChat {
  GroupChat({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
    this.profilePicture,
  });

  final int id;
  final int groupId;
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;
  final String? profilePicture;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'user_name': userName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'profile_picture': profilePicture,
    };
  }

  factory GroupChat.fromMap(Map<String, dynamic> map) {
    // Check if profiles join data is present (Supabase)
    final profileData = map['profiles'] as Map<String, dynamic>?;

    return GroupChat(
      id: map['id'] as int,
      groupId: map['group_id'] as int,
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name'] as String,
      message: map['message'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      profilePicture: map['profile_picture'] as String? ?? profileData?['profile_picture'] as String?,
    );
  }
}
