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
  final String userId;
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
      id: map['id'] as int? ?? 0,
      groupId: map['group_id'] as int? ?? 0,
      userId: map['user_id'].toString(),
      userName: map['user_name'] as String? ?? 'Unknown',
      joinedAt: map['joined_at'] != null 
          ? DateTime.parse(map['joined_at'] as String) 
          : DateTime.now(),
      paidContributions: map['paid_contributions'] as int? ?? 0,
      receivedPayouts: map['received_payouts'] as int? ?? 0,
      rotationOrder: map['rotation_order'] as int? ?? 0,
    );
  }
}