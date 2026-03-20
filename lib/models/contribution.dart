class Contribution {
  Contribution({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.amount,
    required this.round,
    required this.status,
    required this.dueDate,
    this.paidAt,
    this.recipientId,
  });

  final int id;
  final int groupId;
  final String userId;
  final double amount;
  final int round;
  final String status;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String? recipientId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'amount': amount,
      'round': round,
      'status': status,
      'due_date': dueDate.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'recipient_id': recipientId,
    };
  }

  factory Contribution.fromMap(Map<String, dynamic> map) {
    return Contribution(
      id: map['id'] as int,
      groupId: map['group_id'] as int,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      round: map['round'] as int,
      status: map['status'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at'] as String) : null,
      recipientId: map['recipient_id'] as String?,
    );
  }
}