class PaluwaganGroup {
  PaluwaganGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.totalPot,
    required this.contribution,
    required this.frequency,
    required this.maxMembers,
    required this.currentMembers,
    required this.nextPayoutDate,
    required this.createdBy,
    required this.joinCode,
    required this.status,
    required this.currentRound,
    this.createdAt,
    this.groupStatus = 'pending', // 'pending', 'active', 'completed'
  });

  final int id;
  final String name;
  final String description;
  final double totalPot;
  final double contribution;
  final String frequency;
  final int maxMembers;
  final int currentMembers;
  final DateTime nextPayoutDate;
  final String createdBy;
  final String joinCode;
  final String
  status; // 'active', 'completed', 'pending' - for backward compatibility
  final int currentRound;
  final DateTime? createdAt;
  final String groupStatus; // New field for group start status

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'total_pot': totalPot,
      'contribution': contribution,
      'frequency': frequency,
      'max_members': maxMembers,
      'current_members': currentMembers,
      'next_payout_date': nextPayoutDate.toIso8601String(),
      'created_by': createdBy,
      'join_code': joinCode,
      'status': status,
      'current_round': currentRound,
      'created_at': createdAt?.toIso8601String(),
      'group_status': groupStatus,
    };
  }

  factory PaluwaganGroup.fromMap(Map<String, dynamic> map) {
    return PaluwaganGroup(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String,
      totalPot: (map['total_pot'] as num).toDouble(),
      contribution: (map['contribution'] as num).toDouble(),
      frequency: map['frequency'] as String,
      maxMembers: map['max_members'] as int,
      currentMembers: map['current_members'] as int,
      nextPayoutDate: DateTime.parse(map['next_payout_date'] as String),
      createdBy: map['created_by'].toString(),
      joinCode: map['join_code'] as String,
      status: map['status'] as String,
      currentRound: map['current_round'] as int,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      groupStatus: map['group_status'] as String? ?? 'pending',
    );
  }
}