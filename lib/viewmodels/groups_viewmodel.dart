import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'dart:math';

import '../services/db_service.dart';
import '../models/paluwagan_group.dart';
import '../models/group_member.dart';
import '../models/contribution.dart';
import '../models/transaction.dart';
import '../models/group_chat.dart';
import '../models/payment_proof.dart';
import '../models/round_rotation.dart';

class GroupsViewModel extends ChangeNotifier {
  GroupsViewModel(this._dbService) {
    // Don't load all groups here, wait for specific user
  }

  final DbService _dbService;

  List<PaluwaganGroup> _groups = [];
  List<GroupMember> _currentGroupMembers = [];
  List<Contribution> _currentGroupContributions = [];
  List<Transaction> _currentGroupTransactions = [];
  List<GroupChat> _currentGroupChats = [];
  List<PaymentProof> _pendingPayments = [];
  List<RoundRotation> _roundRotations = [];

  PaluwaganGroup? _currentGroup;
  bool _isLoading = false;
  String? _errorMessage;

  List<PaluwaganGroup> get groups => _groups;
  PaluwaganGroup? get currentGroup => _currentGroup;
  List<GroupMember> get currentGroupMembers => _currentGroupMembers;
  List<Contribution> get currentGroupContributions =>
      _currentGroupContributions;
  List<Transaction> get currentGroupTransactions => _currentGroupTransactions;
  List<GroupChat> get currentGroupChats => _currentGroupChats;
  List<PaymentProof> get pendingPayments => _pendingPayments;
  List<RoundRotation> get roundRotations => _roundRotations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Add public getter for DbService (for backward compatibility)
  DbService get dbService => _dbService;

  // New method to load groups for a specific user
  Future<void> loadUserGroups(int userId) async {
    _setLoading(true);
    final db = await _dbService.database;

    try {
      print('=== loadUserGroups START ===');
      print('Loading groups for user ID: $userId');

      // Get groups where user is creator OR member
      final rows = await db.rawQuery(
        '''
        SELECT DISTINCT g.* FROM groups g
        LEFT JOIN group_members gm ON g.id = gm.group_id
        WHERE g.created_by = ? OR gm.user_id = ?
        ORDER BY g.id ASC
      ''',
        [userId, userId],
      );

      print('Found ${rows.length} groups for user');
      _groups = rows.map((row) => PaluwaganGroup.fromMap(row)).toList();
      _errorMessage = null;
      print('=== loadUserGroups END ===');
    } catch (e) {
      print('!!! Error loading user groups: $e');
      print('Stack trace: ${StackTrace.current}');
      _errorMessage = 'Failed to load groups';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  DateTime _calculateNextPayoutDate(String frequency) {
    final now = DateTime.now();
    switch (frequency.toLowerCase()) {
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(now.year, now.month + 1, now.day);
      default:
        return now.add(const Duration(days: 30));
    }
  }

  Future<String> createGroup({
    required String name,
    required String description,
    required double totalPot,
    required double contribution,
    required String frequency,
    required int maxMembers,
    required int createdBy,
  }) async {
    final db = await _dbService.database;
    _setLoading(true);
    _errorMessage = null;

    try {
      print('=== createGroup START ===');
      print('Creating group with name: $name');
      print('Created by user ID: $createdBy');

      // Generate random join code
      final joinCode = _generateJoinCode();
      print('Generated join code: $joinCode');

      // Calculate next payout date based on frequency
      final nextPayoutDate = _calculateNextPayoutDate(frequency);
      print('Next payout date: $nextPayoutDate');

      // Get creator's name
      final userRows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [createdBy],
        limit: 1,
      );

      if (userRows.isEmpty) {
        print('!!! Creator not found with ID: $createdBy');
        _errorMessage = 'Creator user not found';
        return '';
      }

      final creatorName = userRows.isNotEmpty
          ? userRows.first['full_name'] as String
          : 'Creator';
      print('Creator name: $creatorName');

      final groupId = await db.insert('groups', {
        'name': name,
        'description': description,
        'total_pot': totalPot,
        'contribution': contribution,
        'frequency': frequency,
        'max_members': maxMembers,
        'current_members': 1, // Creator is first member
        'next_payout_date': nextPayoutDate.toIso8601String(),
        'created_by': createdBy,
        'join_code': joinCode,
        'status': 'active',
        'group_status': 'pending', // Group starts as pending
        'current_round': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Group inserted with ID: $groupId');

      // Add creator as first member
      await db.insert('group_members', {
        'group_id': groupId,
        'user_id': createdBy,
        'user_name': creatorName,
        'joined_at': DateTime.now().toIso8601String(),
        'paid_contributions': 0,
        'received_payouts': 0,
        'rotation_order': 1, // Temporary order
      });
      print('Creator added as member');

      // Create initial contributions for all rounds
      await _createInitialContributions(
        db,
        groupId,
        createdBy,
        contribution,
        maxMembers,
      );
      print('Initial contributions created');

      // Create notification for group creation
      await db.insert('notifications', {
        'user_id': createdBy,
        'title': 'Group Created',
        'message':
            'You created the group "$name". Share the join code to invite members.',
        'type': 'group_created',
        'group_id': groupId,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('Notification created');

      // Load updated groups for this user
      await loadUserGroups(createdBy);
      print('Groups reloaded for user $createdBy, count: ${_groups.length}');

      print('=== createGroup SUCCESS ===');
      return joinCode;
    } catch (e) {
      print('!!! Error creating group: $e');
      print('Stack trace: ${StackTrace.current}');
      _errorMessage = 'Failed to create group';
      return '';
    } finally {
      _setLoading(false);
    }
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }

  Future<void> _createInitialContributions(
    Database db,
    int groupId,
    int userId,
    double contribution,
    int maxMembers,
  ) async {
    final now = DateTime.now();

    for (int round = 1; round <= maxMembers; round++) {
      final dueDate = now.add(Duration(days: 30 * round));
      await db.insert('contributions', {
        'group_id': groupId,
        'user_id': userId,
        'amount': contribution,
        'round': round,
        'status': 'pending',
        'due_date': dueDate.toIso8601String(),
      });
    }
  }

  Future<bool> joinGroup(String joinCode, int userId, String userName) async {
    final db = await _dbService.database;
    _setLoading(true);
    _errorMessage = null;

    try {
      print('=== joinGroup START ===');
      print('Join code: $joinCode');
      print('User ID: $userId');
      print('User name: $userName');

      // Find group by join code
      final groupRows = await db.query(
        'groups',
        where: 'join_code = ? AND status = ?',
        whereArgs: [joinCode, 'active'],
        limit: 1,
      );

      print('Group query result count: ${groupRows.length}');

      if (groupRows.isEmpty) {
        print('!!! Group not found with code: $joinCode');
        _errorMessage = 'Invalid join code';
        return false;
      }

      final group = PaluwaganGroup.fromMap(groupRows.first);
      print('Group found: ${group.name} (ID: ${group.id})');
      print('Current members: ${group.currentMembers}/${group.maxMembers}');
      print('Group status: ${group.groupStatus}');

      // Check if group is full
      if (group.currentMembers >= group.maxMembers) {
        print('!!! Group is full');
        _errorMessage = 'Group is already full';
        return false;
      }

      // Check if user is already in group
      final existingMember = await db.query(
        'group_members',
        where: 'group_id = ? AND user_id = ?',
        whereArgs: [group.id, userId],
      );

      print('Existing member check: ${existingMember.isNotEmpty}');

      if (existingMember.isNotEmpty) {
        print('!!! User already in group');
        _errorMessage = 'You are already a member of this group';
        return false;
      }

      // Get current members to determine rotation order
      final currentMembers = await db.query(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [group.id],
      );

      final newRotationOrder = currentMembers.length + 1;
      print('New rotation order: $newRotationOrder');

      // Add member to group
      await db.insert('group_members', {
        'group_id': group.id,
        'user_id': userId,
        'user_name': userName,
        'joined_at': DateTime.now().toIso8601String(),
        'paid_contributions': 0,
        'received_payouts': 0,
        'rotation_order': newRotationOrder, // Temporary order
      });
      print('Member added successfully');

      // Create contributions for the new member for all rounds
      for (int round = 1; round <= group.maxMembers; round++) {
        final dueDate = DateTime.now().add(Duration(days: 30 * round));
        await db.insert('contributions', {
          'group_id': group.id,
          'user_id': userId,
          'amount': group.contribution,
          'round': round,
          'status': 'pending',
          'due_date': dueDate.toIso8601String(),
        });
      }
      print('Contributions created for ${group.maxMembers} rounds');

      // Update group member count
      final newMemberCount = group.currentMembers + 1;
      await db.update(
        'groups',
        {'current_members': newMemberCount},
        where: 'id = ?',
        whereArgs: [group.id],
      );
      print('Group member count updated to $newMemberCount');

      // NOTE: Group will NOT auto-start when full
      // Creator must manually click START GROUP button

      // Add welcome notification
      await db.insert('notifications', {
        'user_id': userId,
        'title': 'Welcome to the Group!',
        'message': 'You have successfully joined ${group.name}',
        'type': 'group_joined',
        'group_id': group.id,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('Welcome notification added');

      // IMPORTANT: Reload groups for this user
      await loadUserGroups(userId);
      print('Groups reloaded for user $userId, count: ${_groups.length}');

      print('=== joinGroup SUCCESS ===');
      return true;
    } catch (e) {
      print('!!! Error joining group: $e');
      print('Stack trace: ${StackTrace.current}');
      _errorMessage = 'Failed to join group';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Method to start group manually
  Future<bool> startGroup(int groupId) async {
    return await _startGroup(groupId);
  }

  Future<bool> _startGroup(int groupId) async {
    final db = await _dbService.database;

    try {
      print('=== startGroup START ===');
      print('Starting group ID: $groupId');

      // Get all members
      final memberRows = await db.query(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );

      final members = memberRows
          .map((row) => GroupMember.fromMap(row))
          .toList();

      print('Found ${members.length} members');

      // Randomize rotation order
      await _randomizeRotationOrder(groupId, members);
      print('Rotation order randomized');

      // Get the group details
      final groupRows = await db.query(
        'groups',
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );

      final group = PaluwaganGroup.fromMap(groupRows.first);
      print('Group name: ${group.name}');

      // Get members with updated rotation order
      final updatedMembers = await db.query(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'rotation_order ASC',
      );

      final shuffledMembers = updatedMembers
          .map((row) => GroupMember.fromMap(row))
          .toList();

      // Calculate the start date for first payout
      final firstPayoutDate = _calculateNextPayoutDate(group.frequency);
      print('First payout date: $firstPayoutDate');

      // Create ONLY round rotations (contributions already exist from member joins)
      for (int round = 1; round <= group.maxMembers; round++) {
        final recipient = shuffledMembers[round - 1];
        final roundPayoutDate = firstPayoutDate.add(
          Duration(days: 30 * (round - 1)),
        );

        // Insert round rotation
        // Round 1 gets auto-assigned recipient, others are pending (will be assigned via auto-roll when date arrives)
        await db.insert('round_rotations', {
          'group_id': groupId,
          'round': round,
          'payout_date': roundPayoutDate.toIso8601String(),
          'recipient_id': round == 1
              ? recipient.userId
              : 0, // Only assign Round 1, others are 0 (pending)
          'recipient_name': round == 1 ? recipient.userName : 'TBD',
          'status': round == 1 ? 'in_progress' : 'pending',
        });
      }
      print('Round rotations created');

      // Update contribution due dates now that group has started
      for (int round = 1; round <= group.maxMembers; round++) {
        final roundPayoutDate = firstPayoutDate.add(
          Duration(days: 30 * (round - 1)),
        );
        final dueDate = roundPayoutDate.subtract(const Duration(days: 3));

        await db.update(
          'contributions',
          {'due_date': dueDate.toIso8601String()},
          where: 'group_id = ? AND round = ?',
          whereArgs: [groupId, round],
        );
      }
      print('Contribution due dates updated');

      // Update group status to active
      await db.update(
        'groups',
        {
          'group_status': 'active',
          'status': 'active',
          'current_round': 1,
          'next_payout_date': firstPayoutDate.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [groupId],
      );
      print('Group status updated to active');

      // Notify all members
      for (final member in members) {
        await db.insert('notifications', {
          'user_id': member.userId,
          'title': 'Group Started!',
          'message':
              '${group.name} has started! Check the schedule for your payout round.',
          'type': 'group_started',
          'group_id': groupId,
          'is_read': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      print('Notifications sent to all members');

      await loadGroupDetails(groupId);
      print('=== startGroup SUCCESS ===');
      return true;
    } catch (e) {
      print('!!! Error starting group: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  Future<void> _randomizeRotationOrder(
    int groupId,
    List<GroupMember> members,
  ) async {
    final db = await _dbService.database;

    // Create a list of member IDs and shuffle them
    final shuffledMembers = List<GroupMember>.from(members);
    shuffledMembers.shuffle(Random());

    // Update rotation order
    for (int i = 0; i < shuffledMembers.length; i++) {
      final member = shuffledMembers[i];
      await db.update(
        'group_members',
        {'rotation_order': i + 1},
        where: 'group_id = ? AND user_id = ?',
        whereArgs: [groupId, member.userId],
      );
    }
  }

  Future<void> loadGroupDetails(int groupId) async {
    final db = await _dbService.database;
    _setLoading(true);

    try {
      print('=== loadGroupDetails START ===');
      print('Loading details for group ID: $groupId');

      // Load group
      final groupRows = await db.query(
        'groups',
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );

      if (groupRows.isNotEmpty) {
        _currentGroup = PaluwaganGroup.fromMap(groupRows.first);
        print('Group loaded: ${_currentGroup?.name}');
      } else {
        print('!!! Group not found with ID: $groupId');
      }

      // Load members
      final memberRows = await db.query(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'rotation_order ASC',
      );
      _currentGroupMembers = memberRows
          .map((row) => GroupMember.fromMap(row))
          .toList();
      print('Members loaded: ${_currentGroupMembers.length}');

      // Load contributions
      final contributionRows = await db.query(
        'contributions',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'round ASC, due_date ASC',
      );
      _currentGroupContributions = contributionRows
          .map((row) => Contribution.fromMap(row))
          .toList();
      print('Contributions loaded: ${_currentGroupContributions.length}');

      // Load transactions
      final transactionRows = await db.query(
        'transactions',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'date DESC',
      );
      _currentGroupTransactions = transactionRows
          .map((row) => Transaction.fromMap(row))
          .toList();
      print('Transactions loaded: ${_currentGroupTransactions.length}');

      // Load chat messages
      final chatRows = await db.query(
        'group_chat',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'timestamp ASC',
      );
      _currentGroupChats = chatRows
          .map((row) => GroupChat.fromMap(row))
          .toList();
      print('Chat messages loaded: ${_currentGroupChats.length}');

      // Load pending payments
      final paymentRows = await db.query(
        'payment_proofs',
        where: 'group_id = ? AND status = ?',
        whereArgs: [groupId, 'pending'],
        orderBy: 'submitted_at DESC',
      );
      _pendingPayments = paymentRows
          .map((row) => PaymentProof.fromMap(row))
          .toList();
      print('Pending payments loaded: ${_pendingPayments.length}');

      // Load round rotations
      final rotationRows = await db.query(
        'round_rotations',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'round ASC',
      );
      _roundRotations = rotationRows
          .map((row) => RoundRotation.fromMap(row))
          .toList();
      print('Round rotations loaded: ${_roundRotations.length}');

      // Auto-assign recipients for rounds that reached their date
      await _autoRollRounds(db, groupId);

      print('=== loadGroupDetails END ===');
    } catch (e) {
      print('!!! Error loading group details: $e');
      print('Stack trace: ${StackTrace.current}');
      _errorMessage = 'Failed to load group details';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _autoRollRounds(Database db, int groupId) async {
    try {
      final now = DateTime.now();

      // Get all round rotations
      final rotationRows = await db.query(
        'round_rotations',
        where: 'group_id = ? AND status = ?',
        whereArgs: [groupId, 'pending'],
        orderBy: 'round ASC',
      );

      // Get all member IDs in the group
      final memberRows = await db.query(
        'group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );

      final members = memberRows
          .map((row) => GroupMember.fromMap(row))
          .toList();

      if (members.isEmpty) return;

      // For each pending round, check if its date has passed
      for (final rotationRow in rotationRows) {
        final rotation = RoundRotation.fromMap(rotationRow);
        final payoutDate = DateTime.parse(rotation.payoutDate as String);

        // If payout date has passed and round still doesn't have a recipient, auto-assign
        if (now.isAfter(payoutDate) && rotation.recipientId == 0) {
          // Randomly select a member
          final randomMember = members[Random().nextInt(members.length)];

          // Update the round rotation with the new recipient
          await db.update(
            'round_rotations',
            {
              'recipient_id': randomMember.userId,
              'recipient_name': randomMember.userName,
              'status': 'in_progress',
            },
            where: 'id = ?',
            whereArgs: [rotation.id],
          );
          print(
            'Auto-rolled round ${rotation.round} to ${randomMember.userName}',
          );
        }
      }
    } catch (e) {
      print('Error in auto-roll rounds: $e');
    }
  }

  Future<void> sendChatMessage(
    int groupId,
    int userId,
    String userName,
    String message,
  ) async {
    final db = await _dbService.database;

    try {
      await db.insert('group_chat', {
        'group_id': groupId,
        'user_id': userId,
        'user_name': userName,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Reload chats
      final chatRows = await db.query(
        'group_chat',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'timestamp ASC',
      );
      _currentGroupChats = chatRows
          .map((row) => GroupChat.fromMap(row))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error sending message: $e');
      _errorMessage = 'Failed to send message';
    }
  }

  Future<bool> submitPaymentProof({
    required int groupId,
    required int contributionId,
    required int senderId,
    required String senderName,
    required int recipientId,
    required String recipientName,
    required int round,
    required String gcashName,
    required String gcashNumber,
    required String transactionNo,
    required String screenshotPath,
    required double amount,
  }) async {
    final db = await _dbService.database;
    _setLoading(true);
    _errorMessage = null;

    try {
      print('=== submitPaymentProof START ===');
      print('Group ID: $groupId, Round: $round');
      print('Sender: $senderName, Recipient: $recipientName');

      // Check if group has started
      final groupRows = await db.query(
        'groups',
        where: 'id = ?',
        whereArgs: [groupId],
      );

      if (groupRows.isEmpty) {
        print('!!! Group not found');
        _errorMessage = 'Group not found';
        return false;
      }

      final group = PaluwaganGroup.fromMap(groupRows.first);
      if (group.groupStatus == 'pending') {
        print('!!! Group not started');
        _errorMessage =
            'Cannot make payment - group has not started yet. Payments can only be made after the group is active.';
        return false;
      }

      // Check if payment proof already exists
      final existing = await db.query(
        'payment_proofs',
        where: 'contribution_id = ?',
        whereArgs: [contributionId],
      );

      if (existing.isNotEmpty) {
        print('!!! Payment already submitted');
        _errorMessage = 'Payment already submitted for this contribution';
        return false;
      }

      // Insert payment proof
      await db.insert('payment_proofs', {
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
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });
      print('Payment proof inserted');

      // Update contribution status to pending verification
      await db.update(
        'contributions',
        {'status': 'pending_verification'},
        where: 'id = ?',
        whereArgs: [contributionId],
      );
      print('Contribution status updated');

      // Notify recipient
      await db.insert('notifications', {
        'user_id': recipientId,
        'title': 'Payment Pending Verification',
        'message':
            '$senderName has submitted payment for Round $round. Please verify.',
        'type': 'payment_pending',
        'group_id': groupId,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('Notification sent to recipient');

      // Reload group details
      await loadGroupDetails(groupId);

      print('=== submitPaymentProof SUCCESS ===');
      return true;
    } catch (e) {
      print('!!! Error submitting payment proof: $e');
      print('Stack trace: ${StackTrace.current}');
      _errorMessage = 'Failed to submit payment';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Add this new method to get user by ID
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<bool> verifyPayment(int paymentProofId, int verifierId) async {
    final db = await _dbService.database;
    _setLoading(true);
    _errorMessage = null;

    try {
      print('=== verifyPayment START ===');
      print('Payment proof ID: $paymentProofId');
      print('Verifier ID: $verifierId');

      // Get payment proof details
      final proofRows = await db.query(
        'payment_proofs',
        where: 'id = ?',
        whereArgs: [paymentProofId],
        limit: 1,
      );

      if (proofRows.isEmpty) {
        print('!!! Payment proof not found');
        _errorMessage = 'Payment proof not found';
        return false;
      }

      final proof = PaymentProof.fromMap(proofRows.first);
      print('Proof details - Round: ${proof.round}, Amount: ${proof.amount}');

      // Update payment proof
      await db.update(
        'payment_proofs',
        {
          'status': 'verified',
          'verified_at': DateTime.now().toIso8601String(),
          'verified_by_id': verifierId,
        },
        where: 'id = ?',
        whereArgs: [paymentProofId],
      );
      print('Payment proof verified');

      // Update contribution
      await db.update(
        'contributions',
        {'status': 'paid', 'paid_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [proof.contributionId],
      );
      print('Contribution marked as paid');

      // Create transaction record
      await db.insert('transactions', {
        'group_id': proof.groupId,
        'user_id': proof.senderId,
        'type': 'contribution',
        'amount': proof.amount,
        'round': proof.round,
        'date': DateTime.now().toIso8601String(),
        'description': 'Contribution for round ${proof.round} (Verified)',
      });
      print('Transaction record created');

      // Update member's paid contributions count
      await db.execute(
        '''
        UPDATE group_members 
        SET paid_contributions = paid_contributions + 1 
        WHERE group_id = ? AND user_id = ?
        ''',
        [proof.groupId, proof.senderId],
      );
      print('Member paid contributions updated');

      // Notify sender
      await db.insert('notifications', {
        'user_id': proof.senderId,
        'title': 'Payment Verified',
        'message':
            'Your payment for Round ${proof.round} has been verified by ${proof.recipientName}.',
        'type': 'payment_verified',
        'group_id': proof.groupId,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('Notification sent to sender');

      // Check if all contributions for this round are paid
      final roundContributions = await db.query(
        'contributions',
        where: 'group_id = ? AND round = ? AND status != ?',
        whereArgs: [proof.groupId, proof.round, 'paid'],
      );

      // If all paid, process payout automatically
      if (roundContributions.isEmpty) {
        print(
          'All contributions for round ${proof.round} are paid, processing payout',
        );
        await _processPayout(proof.groupId, proof.round);
      }

      await loadGroupDetails(proof.groupId);

      print('=== verifyPayment SUCCESS ===');
      return true;
    } catch (e) {
      print('!!! Error verifying payment: $e');
      print('Stack trace: ${StackTrace.current}');
      _errorMessage = 'Failed to verify payment';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rejectPayment(int paymentProofId, String reason) async {
    final db = await _dbService.database;
    _setLoading(true);
    _errorMessage = null;

    try {
      print('=== rejectPayment START ===');
      print('Payment proof ID: $paymentProofId');
      print('Rejection reason: $reason');

      // Get payment proof details
      final proofRows = await db.query(
        'payment_proofs',
        where: 'id = ?',
        whereArgs: [paymentProofId],
        limit: 1,
      );

      if (proofRows.isEmpty) {
        print('!!! Payment proof not found');
        _errorMessage = 'Payment proof not found';
        return false;
      }

      final proof = PaymentProof.fromMap(proofRows.first);

      // Update payment proof
      await db.update(
        'payment_proofs',
        {'status': 'rejected', 'rejection_reason': reason},
        where: 'id = ?',
        whereArgs: [paymentProofId],
      );
      print('Payment proof rejected');

      // Reset contribution status
      await db.update(
        'contributions',
        {'status': 'pending'},
        where: 'id = ?',
        whereArgs: [proof.contributionId],
      );
      print('Contribution status reset to pending');

      // Notify sender
      await db.insert('notifications', {
        'user_id': proof.senderId,
        'title': 'Payment Rejected',
        'message':
            'Your payment for Round ${proof.round} was rejected. Reason: $reason',
        'type': 'payment_rejected',
        'group_id': proof.groupId,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('Rejection notification sent');

      await loadGroupDetails(proof.groupId);

      print('=== rejectPayment SUCCESS ===');
      return true;
    } catch (e) {
      print('!!! Error rejecting payment: $e');
      print('Stack trace: ${StackTrace.current}');
      _errorMessage = 'Failed to reject payment';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _processPayout(int groupId, int round) async {
    final db = await _dbService.database;

    try {
      print('=== _processPayout START ===');
      print('Group ID: $groupId, Round: $round');

      // Get round rotation
      final rotationRows = await db.query(
        'round_rotations',
        where: 'group_id = ? AND round = ?',
        whereArgs: [groupId, round],
        limit: 1,
      );

      if (rotationRows.isEmpty) {
        print('!!! Round rotation not found');
        return false;
      }

      final rotation = RoundRotation.fromMap(rotationRows.first);
      print(
        'Recipient ID: ${rotation.recipientId}, Name: ${rotation.recipientName}',
      );

      // Get group details
      final groupRows = await db.query(
        'groups',
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );

      final group = PaluwaganGroup.fromMap(groupRows.first);
      print('Group total pot: ${group.totalPot}');

      // Calculate payout amount (total pot minus 20% fee)
      final payoutAmount = group.totalPot * 0.8; // 20% fee
      print('Payout amount (after 20% fee): $payoutAmount');

      // Create payout transaction
      await db.insert('transactions', {
        'group_id': groupId,
        'user_id': rotation.recipientId,
        'type': 'payout',
        'amount': payoutAmount,
        'round': round,
        'date': DateTime.now().toIso8601String(),
        'description': 'Payout for round $round',
      });
      print('Payout transaction created');

      // Update round rotation
      await db.update(
        'round_rotations',
        {
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
          'total_collected': payoutAmount,
        },
        where: 'id = ?',
        whereArgs: [rotation.id],
      );
      print('Round rotation updated to completed');

      // Update member's received payouts
      await db.execute(
        '''
        UPDATE group_members 
        SET received_payouts = received_payouts + 1 
        WHERE group_id = ? AND user_id = ?
        ''',
        [groupId, rotation.recipientId],
      );
      print('Member received payouts updated');

      // Check if there's a next round
      if (round < group.maxMembers) {
        // Update next round status
        await db.update(
          'round_rotations',
          {'status': 'in_progress'},
          where: 'group_id = ? AND round = ?',
          whereArgs: [groupId, round + 1],
        );
        print('Next round (${round + 1}) set to in_progress');

        // Update group's current round
        await db.update(
          'groups',
          {
            'current_round': round + 1,
            'next_payout_date': _calculateNextPayoutDate(
              group.frequency,
            ).toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [groupId],
        );
        print('Group current round updated to ${round + 1}');

        // Notify next recipient
        final nextRotation = await db.query(
          'round_rotations',
          where: 'group_id = ? AND round = ?',
          whereArgs: [groupId, round + 1],
          limit: 1,
        );

        if (nextRotation.isNotEmpty) {
          final next = RoundRotation.fromMap(nextRotation.first);
          await db.insert('notifications', {
            'user_id': next.recipientId,
            'title': 'It\'s Your Payout Round!',
            'message':
                'Round ${round + 1} has started. You will receive payments from members.',
            'type': 'payout_round_started',
            'group_id': groupId,
            'is_read': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
          print('Next recipient notification sent');
        }
      } else {
        // Group completed
        await db.update(
          'groups',
          {'status': 'completed', 'group_status': 'completed'},
          where: 'id = ?',
          whereArgs: [groupId],
        );
        print('Group completed!');

        // Notify all members
        final members = await db.query(
          'group_members',
          where: 'group_id = ?',
          whereArgs: [groupId],
        );

        for (final member in members) {
          await db.insert('notifications', {
            'user_id': member['user_id'],
            'title': 'Paluwagan Completed!',
            'message':
                'Congratulations! ${group.name} has successfully completed all rounds.',
            'type': 'group_completed',
            'group_id': groupId,
            'is_read': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        print('Completion notifications sent to all members');
      }

      print('=== _processPayout SUCCESS ===');
      return true;
    } catch (e) {
      print('!!! Error processing payout: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // For backward compatibility
  Future<bool> payContribution(int contributionId) async {
    final db = await _dbService.database;

    try {
      final now = DateTime.now();

      // Update contribution
      await db.update(
        'contributions',
        {'status': 'paid', 'paid_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [contributionId],
      );

      // Get contribution details
      final contributionRows = await db.query(
        'contributions',
        where: 'id = ?',
        whereArgs: [contributionId],
        limit: 1,
      );

      if (contributionRows.isNotEmpty) {
        final contribution = Contribution.fromMap(contributionRows.first);

        // Create transaction record
        await db.insert('transactions', {
          'group_id': contribution.groupId,
          'user_id': contribution.userId,
          'type': 'contribution',
          'amount': contribution.amount,
          'round': contribution.round,
          'date': now.toIso8601String(),
          'description': 'Contribution for round ${contribution.round}',
        });

        // Update member's paid contributions count
        await db.execute(
          '''
          UPDATE group_members 
          SET paid_contributions = paid_contributions + 1 
          WHERE group_id = ? AND user_id = ?
          ''',
          [contribution.groupId, contribution.userId],
        );
      }

      // Reload contributions
      await loadGroupDetails(_currentGroup!.id);
      return true;
    } catch (e) {
      print('Error paying contribution: $e');
      return false;
    }
  }

  Future<bool> processPayout(int groupId, int round) async {
    return await _processPayout(groupId, round);
  }
}