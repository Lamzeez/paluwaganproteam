class Contribution {
  Contribution({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.amount,
    required this.round,
    required this.status,
    required this.dueDate,
    required this.paidAt,
  });

  final int id;
  final int groupId;
  final String userId;
  final double amount;
  final int round;
  final String status; // 'pending', 'paid', 'late'
  final DateTime dueDate;
  final DateTime? paidAt;

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
    };
  }

  factory Contribution.fromMap(Map<String, dynamic> map) {
    return Contribution(
      id: map['id'] as int,
      groupId: map['group_id'] as int,
      userId: map['user_id'].toString(),
      amount: (map['amount'] as num).toDouble(),
      round: map['round'] as int,
      status: map['status'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String)
          : null,
    );
  }
}