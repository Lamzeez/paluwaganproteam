class PaymentProof {
  PaymentProof({
    required this.id,
    required this.contributionId,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.round,
    required this.gcashName,
    required this.gcashNumber,
    required this.transactionNo,
    required this.screenshotPath,
    required this.amount,
    required this.status, // 'pending', 'verified', 'rejected'
    required this.submittedAt,
    this.verifiedAt,
    this.verifiedById,
    this.rejectionReason,
  });

  final int id;
  final int contributionId;
  final int groupId;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final int round;
  final String gcashName;
  final String gcashNumber;
  final String transactionNo;
  final String screenshotPath;
  final double amount;
  final String status;
  final DateTime submittedAt;
  final DateTime? verifiedAt;
  final String? verifiedById;
  final String? rejectionReason;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contribution_id': contributionId,
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'recipient_id': recipientId,
      'recipient_name': recipientName,
      'round': round,
      'gcash_name': gcashName,
      'gcash_number': gcashNumber,
      'transaction_no': transactionNo,
      'screenshot_path': screenshotPath,
      'amount': amount,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'verified_by_id': verifiedById,
      'rejection_reason': rejectionReason,
    };
  }

  factory PaymentProof.fromMap(Map<String, dynamic> map) {
    return PaymentProof(
      id: map['id'] as int,
      contributionId: map['contribution_id'] as int,
      groupId: map['group_id'] as int,
      senderId: map['sender_id']?.toString() ?? '',
      senderName: map['sender_name'] as String,
      recipientId: map['recipient_id']?.toString() ?? '',
      recipientName: map['recipient_name'] as String,
      round: map['round'] as int,
      gcashName: map['gcash_name'] as String,
      gcashNumber: map['gcash_number'] as String,
      transactionNo: map['transaction_no'] as String,
      screenshotPath: map['screenshot_path'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String,
      submittedAt: DateTime.parse(map['submitted_at'] as String),
      verifiedAt: map['verified_at'] != null
          ? DateTime.parse(map['verified_at'] as String)
          : null,
      verifiedById: map['verified_by_id']?.toString(),
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}
