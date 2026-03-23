class Transaction {
  Transaction({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.round,
    required this.date,
    required this.description,
  });

  final int id;
  final int groupId;
  final String userId;
  final String type; // 'contribution', 'payout'
  final double amount;
  final int round;
  final DateTime date;
  final String description;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'round': round,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int,
      groupId: map['group_id'] as int,
      userId: map['user_id']?.toString() ?? '',
      type: map['type'] as String,
      amount: map['amount'] as double,
      round: map['round'] as int,
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String,
    );
  }
}
