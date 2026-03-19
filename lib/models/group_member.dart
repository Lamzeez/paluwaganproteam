class GroupMember {
  GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.joinedAt,
    required this.paidContributions,
    required this.receivedPayouts,
    required this.rotationOrder,
  });

  final int id;
  final int groupId;
  final int userId;
  final String userName;
  final DateTime joinedAt;
  final int paidContributions;
  final int receivedPayouts;
  final int rotationOrder;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'user_name': userName,
      'joined_at': joinedAt.toIso8601String(),
      'paid_contributions': paidContributions,
      'received_payouts': receivedPayouts,
      'rotation_order': rotationOrder,
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] as int,
      groupId: map['group_id'] as int,
      userId: map['user_id'] as int,
      userName: map['user_name'] as String,
      joinedAt: DateTime.parse(map['joined_at'] as String),
      paidContributions: map['paid_contributions'] as int,
      receivedPayouts: map['received_payouts'] as int,
      rotationOrder: map['rotation_order'] as int,
    );
  }
}