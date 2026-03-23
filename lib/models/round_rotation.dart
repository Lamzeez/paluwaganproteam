class RoundRotation {
  RoundRotation({
    required this.id,
    required this.groupId,
    required this.round,
    required this.payoutDate,
    required this.recipientId,
    required this.recipientName,
    required this.status, // 'pending', 'in_progress', 'completed'
    this.completedAt,
    this.totalCollected,
  });

  final int id;
  final int groupId;
  final int round;
  final DateTime payoutDate;
  final String recipientId;
  final String recipientName;
  final String status;
  final DateTime? completedAt;
  final double? totalCollected;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'round': round,
      'payout_date': payoutDate.toIso8601String(),
      'recipient_id': recipientId,
      'recipient_name': recipientName,
      'status': status,
      'completed_at': completedAt?.toIso8601String(),
      'total_collected': totalCollected,
    };
  }

  factory RoundRotation.fromMap(Map<String, dynamic> map) {
    return RoundRotation(
      id: map['id'] as int,
      groupId: map['group_id'] as int,
      round: map['round'] as int,
      payoutDate: DateTime.parse(map['payout_date'] as String),
      recipientId: map['recipient_id']?.toString() ?? '',
      recipientName: map['recipient_name'] as String,
      status: map['status'] as String,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      totalCollected: (map['total_collected'] as num?)?.toDouble(),
    );
  }
}
