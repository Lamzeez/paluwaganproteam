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
    _tabController = TabController(length: 5, vsync: this);
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
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(group.name, style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: group.groupStatus == 'active'
                                ? colorScheme.primary.withOpacity(0.08)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            group.groupStatus == 'active' ? 'Active' : 'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: group.groupStatus == 'active'
                                  ? colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isCreator)
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Join code copied!')),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.key, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Code: ${group.joinCode}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Icon(Icons.copy, size: 12),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Members'),
                    Tab(text: 'Schedule'),
                    Tab(text: 'Payment'),
                    Tab(text: 'Chat'),
                  ],
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: colorScheme.primary,
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

                  // Payment Tab
                  _buildPaymentTab(context, group),

                  // Chat Tab
                  _buildChatTab(
                    context,
                    authVm.currentUser!,
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

                // Get current and next round rotations
                final currentRoundRotation = rotations.firstWhere(
                  (r) => r.round == group.currentRound,
                  orElse: () => RoundRotation(
                    id: 0,
                    groupId: group.id,
                    round: group.currentRound,
                    payoutDate: DateTime.now(),
                    recipientId: '',
                    recipientName: 'TBD',
                    status: 'pending',
                  ),
                );

                final nextRoundRotation = group.currentRound < group.maxMembers
                    ? rotations.firstWhere(
                        (r) => r.round == group.currentRound + 1,
                        orElse: () => RoundRotation(
                          id: 0,
                          groupId: group.id,
                          round: group.currentRound + 1,
                          payoutDate: DateTime.now(),
                          recipientId: '',
                          recipientName: 'TBD',
                          status: 'pending',
                        ),
                      )
                    : null;

                // Check if Round 1 has any payments
                final round1Payments = contributions
                    .where((c) => c.round == 1 && c.status == 'paid')
                    .length;

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

                      // Stats Grid - UPDATED with theme color borders
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
                                : '${group.currentRound}/${group.maxMembers}',
                            icon: Icons.timelapse_outlined,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Payout Information - FIXED OVERFLOW ISSUE
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
                              // Current Round (Payout Now) - FIXED ROW WITH EXPANDED
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.payments, color: colorScheme.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded( // Added Expanded here
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Payout Now',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Round ${group.currentRound}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Recipient: ${currentRoundRotation.recipientName}',
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis, // Added overflow
                                          maxLines: 1, // Added maxLines
                                        ),
                                        Text(
                                          _formatDateWithYear(currentRoundRotation.payoutDate),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8), // Added spacing
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getDaysUntil(currentRoundRotation.payoutDate),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _getDaysUntil(currentRoundRotation.payoutDate).contains('Today')
                                            ? Colors.green
                                            : colorScheme.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis, // Added overflow
                                      maxLines: 1, // Added maxLines
                                    ),
                                  ),
                                ],
                              ),

                              if (nextRoundRotation != null) ...[
                                const Divider(height: 24),

                                // Next Round - FIXED ROW WITH EXPANDED
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.schedule,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded( // Added Expanded here
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Next Payout',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Round ${group.currentRound + 1}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Recipient: ${nextRoundRotation.recipientName}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                            overflow: TextOverflow.ellipsis, // Added overflow
                                            maxLines: 1, // Added maxLines
                                          ),
                                          Text(
                                            _formatDateWithYear(nextRoundRotation.payoutDate),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Cycle Progress
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
                                value: progress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                                minHeight: 8,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${group.currentRound} rounds completed',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (round1Payments > 0)
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    Text(
                                      'Waiting for Round 1 payments...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],

                      // Pending Contributions (for current user) - UPDATED with blue theme color
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
    final isPaymentAvailable =
        group.groupStatus == 'active' &&
        contribution.round == group.currentRound &&
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
    final currentRoundRecipient = groupsVm.roundRotations.firstWhere(
      (r) => r.round == group.currentRound && r.status == 'in_progress',
      orElse: () => RoundRotation(
        id: 0,
        groupId: group.id,
        round: group.currentRound,
        payoutDate: DateTime.now(),
        recipientId: '',
        recipientName: '',
        status: 'pending',
      ),
    );

    // Sort members so the creator is always at the top
    final sortedMembers = List<GroupMember>.from(members);
    sortedMembers.sort((a, b) {
      if (a.userId == group.createdBy) return -1;
      if (b.userId == group.createdBy) return 1;
      return 0;
    });

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
                        if (isCurrentUser) ...[
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
                              'You',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
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
                    Text(
                      'Paid: ${member.paidContributions}  •  Received: ${member.receivedPayouts}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: groupsVm.streamRotations(group.id),
      builder: (context, snapshot) {
        final rotations = snapshot.data?.map((r) => RoundRotation.fromMap(r)).toList() 
            ?? groupsVm.roundRotations;

        if (rotations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Group not started yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Schedule will appear once the group starts',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rotations.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final rotation = rotations[index];
            final isCurrent = rotation.status == 'in_progress';
            final isCompleted = rotation.status == 'completed';

            Color statusColor;
            IconData statusIcon;

            if (isCompleted) {
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
            } else if (isCurrent) {
              statusColor = colorScheme.primary;
              statusIcon = Icons.play_circle;
            } else {
              statusColor = Colors.grey;
              statusIcon = Icons.schedule;
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? colorScheme.primary : Colors.grey.shade200,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${rotation.round}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
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
                            Text(
                              'Round ${rotation.round}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(statusIcon, size: 18, color: statusColor),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recipient: ${rotation.recipientName}',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateWithYear(rotation.payoutDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rotation.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

            // Get current user's contributions
            final userContributions = contributions
                .where((c) => c.userId == currentUser?.id)
                .toList();

            if (userContributions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        size: 64, color: Colors.green.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No payments to show',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: userContributions.length,
              itemBuilder: (context, index) {
                final contribution = userContributions[index];
                final currentRound = rotations.firstWhere(
                  (r) => r.round == contribution.round,
                  orElse: () => RoundRotation(
                    id: 0,
                    groupId: group.id,
                    round: contribution.round,
                    payoutDate: DateTime.now(),
                    recipientId: '',
                    recipientName: 'TBD',
                    status: 'pending',
                  ),
                );

                // Check if payment is available
                final isPaymentAvailable = group.groupStatus == 'active' &&
                    contribution.round == group.currentRound &&
                    contribution.status == 'pending';

                // Check if payment has been submitted
                final hasExistingPayment = groupsVm.pendingPayments.any(
                  (p) => p.contributionId == contribution.id,
                );

                // Determine status text and color
                String statusText;
                Color statusColor;

                if (hasExistingPayment) {
                  statusText = 'Pending Verification';
                  statusColor = Colors.orange;
                } else if (contribution.status == 'paid') {
                  statusText = 'Paid';
                  statusColor = Colors.green;
                } else if (!isPaymentAvailable) {
                  statusText = 'Not Available';
                  statusColor = Colors.grey;
                } else {
                  statusText = 'Pending';
                  statusColor = colorScheme.primary;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Round ${contribution.round} Payment',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Send to: ${currentRound.recipientName}',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due: ${_formatDateWithYear(contribution.dueDate)}',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₱${contribution.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          if (isPaymentAvailable && !hasExistingPayment)
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
                              ),
                              child: const Text('Pay Now'),
                            ),
                        ],
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
  }

  Widget _buildChatTab(
    BuildContext context,
    User currentUser,
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

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat, size: 64, color: Colors.grey.shade400),
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
                        'Be the first to send a message!',
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
                    duration: const Duration(milliseconds: 300),
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