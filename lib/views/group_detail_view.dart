import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/paluwagan_group.dart';
import '../models/group_member.dart';
import '../models/group_chat.dart';
import '../models/user.dart';
import '../models/contribution.dart';
import '../models/payment_proof.dart';
import '../models/round_rotation.dart';
import '../viewmodels/groups_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'gcash_payment_screen.dart';
import 'verify_payment_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroupDetails();
    });
  }

  void _loadGroupDetails() {
    context.read<GroupsViewModel>().loadGroupDetails(widget.groupId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;

    final groupsVm = context.read<GroupsViewModel>();
    final authVm = context.read<AuthViewModel>();

    groupsVm.sendChatMessage(
      widget.groupId,
      authVm.currentUser!.id,
      authVm.currentUser!.fullName,
      _chatController.text.trim(),
    );

    _chatController.clear();

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(
          _chatScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupsVm = context.watch<GroupsViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<Map<String, dynamic>>(
      stream: groupsVm.streamGroup(widget.groupId),
      builder: (context, snapshot) {
        // Fallback to ViewModel data if stream is loading
        final groupData = snapshot.data;
        final group = groupData != null 
            ? PaluwaganGroup.fromMap(groupData) 
            : groupsVm.currentGroup;

        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Group Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

            final isCreator = group.createdBy == authVm.currentUser?.id;
            final progress = group.currentRound / group.maxMembers;
            final isGroupCompleted = group.groupStatus == 'completed';
            
            // Use StreamBuilder for members to keep UI responsive
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: groupsVm.streamMembers(widget.groupId),
              builder: (context, memberSnapshot) {
                final members = memberSnapshot.data?.map((m) => GroupMember.fromMap(m)).toList() 
                    ?? groupsVm.currentGroupMembers;

                final userIsMember = members.any(
                  (m) => m.userId == authVm.currentUser?.id,
                );

                // Check if group is full
                final isGroupFull = members.length >= group.maxMembers;

                if (!userIsMember && !isCreator) {
                  return Scaffold(
                    appBar: AppBar(title: Text(group.name)),
                    body: const Center(child: Text('You are not a member of this group')),
                  );
                }

                return Scaffold(
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0.5,
                    toolbarHeight: isCreator ? 72 : 60,
                    titleSpacing: 0,
                    leading: const BackButton(color: Colors.black87),
                    title: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (isCreator) ...[
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Join code copied!')),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.vpn_key_rounded, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 6),
                                          Text(
                                            group.joinCode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              letterSpacing: 1.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.copy_rounded, size: 10, color: Colors.grey.shade500),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: group.groupStatus == 'active'
                                  ? colorScheme.primary.withOpacity(0.08)
                                  : (group.groupStatus == 'completed'
                                      ? Colors.green.withOpacity(0.08)
                                      : Colors.grey.withOpacity(0.08)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: group.groupStatus == 'active'
                                    ? colorScheme.primary.withOpacity(0.2)
                                    : (group.groupStatus == 'completed'
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2)),
                              ),
                            ),
                            child: Text(
                              (group.groupStatus ?? 'PENDING').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: group.groupStatus == 'active'
                                    ? colorScheme.primary
                                    : (group.groupStatus == 'completed' ? Colors.green : Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      indicatorSize: TabBarIndicatorSize.label,
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      dividerColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      labelPadding: EdgeInsets.zero,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Members'),
                        Tab(text: 'Schedule'),
                        Tab(text: 'Chat'),
                      ],
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: colorScheme.primary,
                      indicatorWeight: 3,
                    ),
                  ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  // Overview Tab
                  _buildOverviewTab(context, group, members, progress, isCreator, isGroupFull),

                  // Members Tab
                  _buildMembersTab(context, members, group),

                  // Schedule Tab
                  _buildScheduleTab(context, group),

                  // Chat Tab
                  _buildChatTab(
                    context,
                    authVm.currentUser!,
                    isGroupCompleted,
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    PaluwaganGroup group,
    List<GroupMember> members,
    double progress,
    bool isCreator,
    bool isGroupFull,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupsVm = context.watch<GroupsViewModel>();
    final currentUser = context.read<AuthViewModel>().currentUser;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: groupsVm.streamRotations(group.id),
      builder: (context, rotationSnapshot) {
        final rotations = rotationSnapshot.data?.map((r) => RoundRotation.fromMap(r)).toList() 
            ?? groupsVm.roundRotations;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: groupsVm.streamContributions(group.id),
          builder: (context, contributionSnapshot) {
            final contributions = contributionSnapshot.data?.map((c) => Contribution.fromMap(c)).toList() 
                ?? groupsVm.currentGroupContributions;

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: groupsVm.streamPaymentProofs(group.id),
              builder: (context, proofSnapshot) {
                final proofs = proofSnapshot.data?.map((p) => PaymentProof.fromMap(p)).toList() 
                    ?? groupsVm.pendingPayments;

                // Derive the ACTUAL current round from rotations
                final activeRotation = rotations.firstWhere(
                  (r) => r.status == 'in_progress',
                  orElse: () => rotations.firstWhere(
                    (r) => r.round == group.currentRound,
                    orElse: () => rotations.isNotEmpty ? rotations.last : RoundRotation(
                      id: 0,
                      groupId: group.id,
                      round: group.currentRound,
                      payoutDate: DateTime.now(),
                      recipientId: '',
                      recipientName: 'TBD',
                      status: 'pending',
                    ),
                  ),
                );

                final actualCurrentRound = activeRotation.round;
                final completedRounds = rotations.where((r) => r.status == 'completed').length;
                final totalRounds = rotations.isNotEmpty ? rotations.length : group.maxMembers;

                // Get creator's name from members list
                final creatorMember = members.firstWhere(
                  (m) => m.userId == group.createdBy,
                  orElse: () => GroupMember(
                    id: 0,
                    groupId: group.id,
                    userId: group.createdBy,
                    userName: 'Creator',
                    joinedAt: DateTime.now(),
                    paidContributions: 0,
                    receivedPayouts: 0,
                    rotationOrder: 0,
                  ),
                );

                // Get current user's pending contributions
                final pendingContributions = contributions
                    .where((c) => c.userId == currentUser?.id && c.status == 'pending')
                    .toList();

                // Get current user's pending verifications (payments they need to verify)
                final pendingVerifications = proofs
                    .where((p) => p.recipientId == currentUser?.id && p.status == 'pending')
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Status Banner
                      if (group.groupStatus == 'pending') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 40,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Group Not Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created by ${creatorMember.userName}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Show different message based on group status
                              if (!isGroupFull)
                                Text(
                                  'Need ${group.maxMembers - members.length} more member(s) to start. Group will be ready to start when full (${group.maxMembers} members).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.orange.shade700),
                                )
                              else
                                Text(
                                  'Group is now full! Ready to start.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                              // Show start button if creator AND group is full
                              if (isCreator && isGroupFull) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Start Group'),
                                        content: Text(
                                          'Are you sure you want to start ${group.name}? '
                                          'Once started, the rotation order will be randomized and rounds will begin.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Start Group'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      final success = await context
                                          .read<GroupsViewModel>()
                                          .startGroup(group.id);
                                      if (success && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Group started successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(200, 45),
                                  ),
                                  child: const Text(
                                    'START GROUP NOW',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],

                              // Delete Group Button for Creator
                              if (isCreator) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Group'),
                                        content: Text(
                                          'Are you sure you want to delete ${group.name}? '
                                          'This action cannot be undone and all data will be lost.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      final success = await context
                                          .read<GroupsViewModel>()
                                          .deleteGroup(group.id);
                                      if (success && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Group deleted successfully'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        Navigator.of(context).pop(); // Go back to Home
                                      }
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    minimumSize: const Size(200, 40),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text('DELETE GROUP'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Pending Verifications Section
                      if (pendingVerifications.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.verified, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pending Verifications (${pendingVerifications.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...pendingVerifications.map(
                                (proof) => _buildPendingVerificationTile(context, proof),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Stats Grid - UPDATED with derived values
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildStatCard(
                            context,
                            label: 'Total Pot',
                            value: '₱${group.totalPot.toStringAsFixed(0)}',
                            icon: Icons.savings_outlined,
                            color: colorScheme.primary,
                          ),
                          _buildStatCard(
                            context,
                            label: 'Members',
                            value: '${members.length}/${group.maxMembers}',
                            icon: Icons.group_outlined,
                            color: members.length >= group.maxMembers
                                ? Colors.green
                                : colorScheme.primary,
                          ),
                          _buildStatCard(
                            context,
                            label: 'Contribution',
                            value: '₱${group.contribution.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: colorScheme.primary,
                          ),
                          _buildStatCard(
                            context,
                            label: 'Current Round',
                            value: group.groupStatus == 'pending'
                                ? 'Not Started'
                                : '$actualCurrentRound/$totalRounds',
                            icon: Icons.timelapse_outlined,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Payout Information - FIXED based on rotation status
                      if (group.groupStatus == 'active') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // All Rounds List
                              ...rotations.map((rotation) {
                                final isCurrent = rotation.status == 'in_progress';
                                final isPast = rotation.status == 'completed';
                                
                                return Column(
                                  children: [
                                    if (rotation.round > 1) const Divider(height: 24),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isCurrent 
                                                ? colorScheme.primary.withOpacity(0.1)
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isCurrent ? Icons.payments : (isPast ? Icons.check_circle : Icons.schedule), 
                                            color: isCurrent ? colorScheme.primary : (isPast ? Colors.green : Colors.grey.shade600)
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isCurrent ? 'Payout Now' : (isPast ? 'Completed' : 'Upcoming Payout'),
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Round ${rotation.round}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'Recipient: ${rotation.recipientName}',
                                                style: const TextStyle(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                              Text(
                                                _formatDateWithYear(rotation.payoutDate),
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isCurrent || isPast)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isPast ? Colors.green : colorScheme.primary).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isPast ? 'DONE' : _getDaysUntil(rotation.payoutDate),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isPast ? Colors.green : colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Cycle Progress - Derived from completed rounds
                        const Text(
                          'Cycle Progress',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: completedRounds / totalRounds,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                                minHeight: 8,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$completedRounds rounds completed',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${((completedRounds / totalRounds) * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],

                      // Pending Contributions (for current user) - Use derived round
                      if (pendingContributions.isNotEmpty) ...[
                        const Text(
                          'Your Pending Contributions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        ...pendingContributions.map(
                          (contribution) => _buildPendingContributionTile(
                            context,
                            group,
                            contribution,
                            rotations,
                            groupsVm,
                            actualCurrentRound,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPendingContributionTile(
    BuildContext context,
    PaluwaganGroup group,
    Contribution contribution,
    List<RoundRotation> rotations,
    GroupsViewModel groupsVm,
    int actualCurrentRound,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final currentRound = rotations.firstWhere(
      (r) => r.round == contribution.round,
      orElse: () => RoundRotation(
        id: 0,
        groupId: group.id,
        round: contribution.round,
        payoutDate: DateTime.now(),
        recipientId: '',
        recipientName: 'Unknown',
        status: 'pending',
      ),
    );

    // Check if payment is available (group is active and it's the current round)
    // Use actualCurrentRound for more dynamic availability
    final isPaymentAvailable =
        group.groupStatus == 'active' &&
        contribution.round == actualCurrentRound &&
        contribution.status == 'pending';

    // Check if payment has already been submitted
    final hasExistingPayment = groupsVm.pendingPayments.any(
      (p) => p.contributionId == contribution.id,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaymentAvailable
              ? colorScheme.primary
              : Colors.grey.shade300,
          width: isPaymentAvailable ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPaymentAvailable
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPaymentAvailable ? Icons.payment : Icons.pending_actions,
                  color: isPaymentAvailable ? colorScheme.primary : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Round ${contribution.round} Contribution',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Send to: ${currentRound.recipientName}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'Due: ${_formatDateWithYear(contribution.dueDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${contribution.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasExistingPayment)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Submitted',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    )
                  else if (!isPaymentAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Not Available',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GcashPaymentScreen(
                              group: group,
                              contribution: contribution,
                              round: contribution.round,
                              recipientId: currentRound.recipientId,
                              recipientName: currentRound.recipientName,
                              amount: contribution.amount,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 36),
                      ),
                      child: const Text('Pay Now'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVerificationTile(
    BuildContext context,
    PaymentProof proof,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            child: Text(
              proof.senderName[0].toUpperCase(),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proof.senderName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'Paid Round ${proof.round} - ₱${proof.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VerifyPaymentScreen(paymentProof: proof),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(
    BuildContext context,
    List<GroupMember> members,
    PaluwaganGroup group,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.read<AuthViewModel>().currentUser;
    final groupsVm = context.watch<GroupsViewModel>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: groupsVm.streamRotations(group.id),
      builder: (context, rotationSnapshot) {
        final rotations = rotationSnapshot.data?.map((r) => RoundRotation.fromMap(r)).toList() 
            ?? groupsVm.roundRotations;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: groupsVm.streamContributions(group.id),
          builder: (context, contributionSnapshot) {
            final contributions = contributionSnapshot.data?.map((c) => Contribution.fromMap(c)).toList() 
                ?? groupsVm.currentGroupContributions;

            // Sort members so the creator is always at the top
            final sortedMembers = List<GroupMember>.from(members);
            sortedMembers.sort((a, b) {
              if (a.userId == group.createdBy) return -1;
              if (b.userId == group.createdBy) return 1;
              return 0;
            });

            final currentRoundRecipient = rotations.firstWhere(
              (r) => r.status == 'in_progress',
              orElse: () => rotations.firstWhere(
                (r) => r.round == group.currentRound,
                orElse: () => rotations.isNotEmpty ? rotations.last : RoundRotation(
                  id: 0,
                  groupId: group.id,
                  round: group.currentRound,
                  payoutDate: DateTime.now(),
                  recipientId: '',
                  recipientName: '',
                  status: 'pending',
                ),
              ),
            );

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedMembers.length,
              itemBuilder: (context, index) {
                final member = sortedMembers[index];
                final isCurrentUser = member.userId == currentUser?.id;
                final isCreator = member.userId == group.createdBy;
                final isPayoutRound =
                    member.userId == currentRoundRecipient.recipientId &&
                    group.groupStatus == 'active';

                // DYNAMIC STATS CALCULATION
                final memberContributions = contributions.where((c) => c.userId == member.userId).toList();
                final paidCount = memberContributions.where((c) => c.status == 'paid').length;
                final receivedCount = rotations.where((r) => r.recipientId == member.userId && r.status == 'completed').length;

                // TRUST SCORE CALCULATION
                // Logic: (On-time payments / Total payments) * 100
                // Late is defined as paid_at > due_date
                double trustScore = 100.0;
                int totalEvaluated = 0;
                int onTimeCount = 0;

                for (var c in memberContributions) {
                  if (c.status == 'paid') {
                    // Check if it's the recipient slot (auto-paid)
                    final isRecipientSlot = rotations.any((r) => r.round == c.round && r.recipientId == c.userId);
                    
                    if (!isRecipientSlot) {
                      totalEvaluated++;
                      if (c.paidAt != null) {
                        // Allow 1 hour grace period for processing
                        final isLate = c.paidAt!.isAfter(c.dueDate.add(const Duration(hours: 1)));
                        if (!isLate) {
                          onTimeCount++;
                        }
                      }
                    }
                  } else if (c.status == 'pending' && c.dueDate.isBefore(DateTime.now())) {
                    // Penalty for overdue unpaid contributions
                    totalEvaluated++;
                  }
                }

                if (totalEvaluated > 0) {
                  trustScore = (onTimeCount / totalEvaluated) * 100;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPayoutRound ? colorScheme.primary : Colors.grey.shade200,
                      width: isPayoutRound ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isCurrentUser
                            ? colorScheme.primary
                            : isCreator 
                                ? Colors.orange.shade100 
                                : Colors.grey.shade300,
                        child: Text(
                          member.userName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            color: isCurrentUser ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    member.userName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isCurrentUser
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (isCreator) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Creator',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isPayoutRound) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Current Payout',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Paid: $paidCount  •  Received: $receivedCount',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const Spacer(),
                                _buildTrustBadge(trustScore, totalEvaluated == 0),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // REMOVE / LEAVE BUTTONS (Only if group not started)
                      if (group.groupStatus == 'pending') ...[
                        if (group.createdBy == currentUser?.id && !isCurrentUser)
                          IconButton(
                            icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
                            onPressed: () async {
                              final confirmed = await _showConfirmDialog(
                                context,
                                'Remove Member',
                                'Are you sure you want to remove ${member.userName} from the group?',
                              );
                              if (confirmed) {
                                await groupsVm.leaveGroup(group.id, member.userId);
                              }
                            },
                          ),
                        if (isCurrentUser && group.createdBy != currentUser?.id)
                          TextButton(
                            onPressed: () async {
                              final confirmed = await _showConfirmDialog(
                                context,
                                'Leave Group',
                                'Are you sure you want to leave ${group.name}?',
                              );
                              if (confirmed) {
                                final success = await groupsVm.leaveGroup(group.id, currentUser!.id);
                                if (success && mounted) {
                                  Navigator.of(context).pop(); // Go back home
                                }
                              }
                            },
                            child: const Text('LEAVE', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ],
                  ),
                );
              },
            );
          }
        );
      }
    );
  }

  Widget _buildTrustBadge(double score, bool isNew) {
    if (isNew) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'NEW',
          style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
        ),
      );
    }

    Color badgeColor = Colors.green;
    if (score < 70) badgeColor = Colors.red;
    else if (score < 90) badgeColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: 10, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            '${score.toStringAsFixed(0)}% Trust',
            style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context, String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(title.split(' ')[0].toUpperCase(), style: const TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildScheduleTab(
    BuildContext context,
    PaluwaganGroup group,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupsVm = context.watch<GroupsViewModel>();
    final currentUser = context.read<AuthViewModel>().currentUser;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: groupsVm.streamRotations(group.id),
      builder: (context, rotationSnapshot) {
        final rotations = rotationSnapshot.data
                ?.map((r) => RoundRotation.fromMap(r))
                .toList() ??
            groupsVm.roundRotations;

        if (rotations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('Group not started yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: groupsVm.streamContributions(group.id),
          builder: (context, contributionSnapshot) {
            final contributions = contributionSnapshot.data
                    ?.map((c) => Contribution.fromMap(c))
                    .toList() ??
                groupsVm.currentGroupContributions;

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: groupsVm.streamPaymentProofs(group.id),
              builder: (context, proofSnapshot) {
                final allProofs = proofSnapshot.data
                        ?.map((p) => PaymentProof.fromMap(p))
                        .toList() ??
                    groupsVm.pendingPayments;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rotations.length,
                  itemBuilder: (context, index) {
                    final rotation = rotations[index];
                    final isCurrent = rotation.status == 'in_progress';
                    final isCompleted = rotation.status == 'completed';
                    final isFuture = rotation.status == 'pending';

                    Color statusColor = isCompleted ? Colors.green : (isCurrent ? colorScheme.primary : Colors.grey);

                    // Filter contributions for THIS specific round
                    final roundContributions = contributions.where((c) => c.round == rotation.round).toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isCurrent ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isCurrent ? colorScheme.primary : Colors.grey.shade200),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: isCurrent,
                        shape: const Border(), // Remove default borders
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Text('${rotation.round}', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text('Round ${rotation.round}', style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text('Recipient: ${rotation.recipientName}', style: const TextStyle(fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(rotation.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                        children: [
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Payout Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(_formatDateWithYear(rotation.payoutDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Round Contributions:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...roundContributions.map((contribution) {
                                  final isUserSlot = contribution.userId == currentUser?.id;
                                  final isRecipientSlot = contribution.userId == rotation.recipientId;
                                  final proof = allProofs.firstWhere(
                                    (p) => p.contributionId == contribution.id,
                                    orElse: () => PaymentProof(id: 0, contributionId: 0, groupId: 0, senderId: '', senderName: '', recipientId: '', recipientName: '', round: 0, gcashName: '', gcashNumber: '', transactionNo: '', screenshotPath: '', amount: 0, status: 'none', submittedAt: DateTime.now()),
                                  );

                                  // Check if current user is the recipient of THIS round
                                  final isUserTheRecipient = rotation.recipientId == currentUser?.id;
                                  
                                  final canPay = isUserSlot && !isRecipientSlot && isCurrent && contribution.status == 'pending' && proof.status == 'none';
                                  final canVerify = isUserTheRecipient && isCurrent && proof.status == 'pending';

                                  Color cStatusColor = contribution.status == 'paid' ? Colors.green : (proof.status == 'pending' ? Colors.orange : Colors.red);
                                  String cStatusText = contribution.status == 'paid' ? (isRecipientSlot ? "Recipient (Skipped)" : "Paid") : (proof.status == 'pending' ? "Pending" : "Unpaid");

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(isUserSlot ? "You" : "Member ${contribution.userId.substring(0, 5)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                              Text('₱${contribution.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        if (proof.status != 'none')
                                          IconButton(
                                            onPressed: () => _showReceiptImage(context, proof.screenshotPath),
                                            icon: const Icon(Icons.receipt_long, size: 18, color: Colors.blue),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        const SizedBox(width: 8),
                                        if (canPay)
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GcashPaymentScreen(group: group, contribution: contribution, round: contribution.round, recipientId: rotation.recipientId, recipientName: rotation.recipientName, amount: contribution.amount)));
                                            },
                                            child: const Text('PAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          )
                                        else if (canVerify)
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerifyPaymentScreen(paymentProof: proof)));
                                            },
                                            child: const Text('VERIFY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                          )
                                        else
                                          Text(cStatusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cStatusColor)),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentTab(
    BuildContext context,
    PaluwaganGroup group,
  ) {
    final currentUser = context.read<AuthViewModel>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final groupsVm = context.watch<GroupsViewModel>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: groupsVm.streamContributions(group.id),
      builder: (context, contributionSnapshot) {
        final contributions = contributionSnapshot.data
                ?.map((c) => Contribution.fromMap(c))
                .toList() ??
            groupsVm.currentGroupContributions;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: groupsVm.streamRotations(group.id),
          builder: (context, rotationSnapshot) {
            final rotations = rotationSnapshot.data
                    ?.map((r) => RoundRotation.fromMap(r))
                    .toList() ??
                groupsVm.roundRotations;

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: groupsVm.streamPaymentProofs(group.id),
              builder: (context, proofSnapshot) {
                final allProofs = proofSnapshot.data
                        ?.map((p) => PaymentProof.fromMap(p))
                        .toList() ??
                    groupsVm.pendingPayments;

                // EVERYONE sees all contributions for the round
                // We filter for the current round to keep it clean
                final currentRoundContributions = contributions
                    .where((c) => c.round == group.currentRound)
                    .toList();

                // Check if current user is the recipient of THIS round
                final currentRotation = rotations.firstWhere(
                  (r) => r.round == group.currentRound,
                  orElse: () => RoundRotation(id: 0, groupId: 0, round: 0, payoutDate: DateTime.now(), recipientId: '', recipientName: '', status: ''),
                );
                final isCurrentRecipient = currentRotation.recipientId == currentUser?.id;

                if (currentRoundContributions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
                        const SizedBox(height: 16),
                        const Text('No payments found for this round', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    if (isCurrentRecipient)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.green),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "It's your turn! You are the recipient this round. Please verify incoming payments below.",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: currentRoundContributions.length,
                        itemBuilder: (context, index) {
                          final contribution = currentRoundContributions[index];
                          final isUserContribution = contribution.userId == currentUser?.id;
                          final isRecipientOfThisSlot = contribution.userId == currentRotation.recipientId;

                          // Find proof if exists
                          final proof = allProofs.firstWhere(
                            (p) => p.contributionId == contribution.id,
                            orElse: () => PaymentProof(id: 0, contributionId: 0, groupId: 0, senderId: '', senderName: '', recipientId: '', recipientName: '', round: 0, gcashName: '', gcashNumber: '', transactionNo: '', screenshotPath: '', amount: 0, status: 'none', submittedAt: DateTime.now()),
                          );

                          // Logic for buttons
                          final canPay = isUserContribution && !isRecipientOfThisSlot && contribution.status == 'pending' && proof.status == 'none';
                          final canVerify = isCurrentRecipient && proof.status == 'pending';

                          Color statusColor;
                          String statusText;
                          if (contribution.status == 'paid') {
                            statusText = isRecipientOfThisSlot ? 'Recipient (Skipped)' : 'Verified & Paid';
                            statusColor = Colors.green;
                          } else if (proof.status == 'pending') {
                            statusText = 'Pending Verification';
                            statusColor = Colors.orange;
                          } else {
                            statusText = 'Unpaid';
                            statusColor = Colors.red;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isUserContribution ? colorScheme.primary : Colors.grey.shade300, width: isUserContribution ? 1.5 : 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isUserContribution ? "Your Contribution" : contribution.userId.substring(0, 8),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('₱${contribution.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    Row(
                                      children: [
                                        if (proof.status == 'pending')
                                          IconButton(
                                            onPressed: () => _showReceiptImage(context, proof.screenshotPath),
                                            icon: const Icon(Icons.receipt_long, color: Colors.blue),
                                            tooltip: 'View Screenshot',
                                          ),
                                        if (canPay)
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GcashPaymentScreen(group: group, contribution: contribution, round: contribution.round, recipientId: currentRotation.recipientId, recipientName: currentRotation.recipientName, amount: contribution.amount)));
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
                                            child: const Text('Pay Now'),
                                          ),
                                        if (canVerify)
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerifyPaymentScreen(paymentProof: proof)));
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                            child: const Text('Verify'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showReceiptImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt Screenshot', style: TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: path.startsWith('http')
                  ? Image.network(path, fit: BoxFit.contain)
                  : Image.file(File(path), fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab(
    BuildContext context,
    User currentUser,
    bool isGroupCompleted,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupsVm = context.read<GroupsViewModel>();

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: groupsVm.streamChat(widget.groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data
                      ?.map((m) => GroupChat.fromMap(m))
                      .toList() ??
                  [];

              // Sort messages by timestamp to ensure correct order
              messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to start the conversation!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Auto-scroll to bottom on new message
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_chatScrollController.hasClients) {
                  _chatScrollController.animateTo(
                    _chatScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });

              return ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.userId == currentUser.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade300,
                            child: Text(
                              message.userName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? colorScheme.primary
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomLeft: isMe
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(
                                    message.userName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  message.message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isMe) const SizedBox(width: 8),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Message Input
        if (!isGroupCompleted)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  backgroundColor: colorScheme.primary,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.grey.shade100,
            width: double.infinity,
            child: const Text(
              'This group is completed. Chat is read-only.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _formatDateWithYear(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getDaysUntil(DateTime date) {
    final days = date.difference(DateTime.now()).inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '$days days left';
  }
}