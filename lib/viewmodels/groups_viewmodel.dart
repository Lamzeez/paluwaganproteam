import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'dart:math';

import '../services/db_service.dart';
import '../services/supabase_service.dart';
import '../models/paluwagan_group.dart';
import '../models/group_member.dart';
import '../models/contribution.dart';
import '../models/transaction.dart';
import '../models/group_chat.dart';
import '../models/payment_proof.dart';
import '../models/round_rotation.dart';
import '../models/user.dart' as user_model;

class GroupsViewModel extends ChangeNotifier {
  GroupsViewModel(this._dbService, this._supabaseService);

  final DbService _dbService;
  final SupabaseService _supabaseService;

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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  // --- CLOUD-PRIORITY METHODS ---

  Future<void> loadUserGroups(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Fetch from Supabase
      final cloudGroups = await _supabaseService.getUserGroups(userId);
      
      // 2. Sync to local SQLite
      final db = await _dbService.database;
      final List<PaluwaganGroup> mappedGroups = [];
      
      for (var row in cloudGroups) {
        // Remove the joined group_members data before mapping to model
        final groupData = Map<String, dynamic>.from(row)..remove('group_members');
        final group = PaluwaganGroup.fromMap(groupData);
        mappedGroups.add(group);
        
        await db.insert('groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      _groups = mappedGroups;
      notifyListeners();
    } catch (e) {
      print('Error loading groups: $e');
      // Fallback to local
      final db = await _dbService.database;
      final rows = await db.rawQuery(
        'SELECT DISTINCT g.* FROM groups g LEFT JOIN group_members gm ON g.id = gm.group_id WHERE g.created_by = ? OR gm.user_id = ?',
        [userId, userId],
      );
      _groups = rows.map((row) => PaluwaganGroup.fromMap(row)).toList();
    } finally {
      _setLoading(false);
    }
  }

  Future<String> createGroup({
    required String name,
    required String description,
    required double totalPot,
    required double contribution,
    required String frequency,
    required int maxMembers,
    required String createdBy,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final joinCode = _generateJoinCode();
      final nextPayoutDate = _calculateNextPayoutDate(frequency);

      // 1. Create in Supabase
      final groupData = {
        'name': name,
        'description': description,
        'total_pot': totalPot,
        'contribution': contribution,
        'frequency': frequency,
        'max_members': maxMembers,
        'current_members': 1,
        'next_payout_date': nextPayoutDate.toIso8601String(),
        'created_by': createdBy,
        'join_code': joinCode,
        'status': 'active',
        'group_status': 'pending',
        'current_round': 1,
        'created_at': DateTime.now().toIso8601String(),
      };

      final cloudGroup = await _supabaseService.createGroup(groupData);
      final groupId = cloudGroup['id'];

      // 2. Add creator as first member in Cloud
      await _supabaseService.addMember({
        'group_id': groupId,
        'user_id': createdBy,
        'joined_at': DateTime.now().toIso8601String(),
        'rotation_order': 1,
      });

      // 3. Sync to local
      final db = await _dbService.database;
      await db.insert('groups', {
        ...groupData,
        'id': groupId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await loadUserGroups(createdBy);
      return joinCode;
    } catch (e) {
      _setError('Failed to create group: $e');
      return '';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> joinGroup(String joinCode, String userId, String userName) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Find group in Cloud
      final groupData = await _supabaseService.findGroupByCode(joinCode);
      if (groupData == null) {
        _setError('Invalid join code');
        return false;
      }

      final group = PaluwaganGroup.fromMap(groupData);
      if (group.currentMembers >= group.maxMembers) {
        _setError('Group is full');
        return false;
      }

      // 2. Add member in Cloud
      await _supabaseService.addMember({
        'group_id': group.id,
        'user_id': userId,
        'user_name': userName,
        'joined_at': DateTime.now().toIso8601String(),
        'rotation_order': group.currentMembers + 1,
      });

      // 3. Update member count in Cloud
      final supabase = _supabaseService; // (Assuming a method or direct client access)
      // For now we'll assume the trigger on the backend or manual update
      // await supabase.client.from('groups').update({'current_members': group.currentMembers + 1}).eq('id', group.id);

      await loadUserGroups(userId);
      return true;
    } catch (e) {
      _setError('Failed to join group: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadGroupDetails(int groupId) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Fetch all related data from Cloud
      final data = await _supabaseService.getGroupDetails(groupId);
      
      _currentGroup = PaluwaganGroup.fromMap(data);
      _currentGroupMembers = (data['group_members'] as List)
          .map((m) => GroupMember.fromMap(m))
          .toList();
      _roundRotations = (data['round_rotations'] as List)
          .map((r) => RoundRotation.fromMap(r))
          .toList();
      _currentGroupContributions = (data['contributions'] as List)
          .map((c) => Contribution.fromMap(c))
          .toList();
      _currentGroupChats = (data['group_chat'] as List)
          .map((ch) => GroupChat.fromMap(ch))
          .toList();
      _pendingPayments = (data['payment_proofs'] as List)
          .map((p) => PaymentProof.fromMap(p))
          .toList();

      // 2. Sync to local SQLite
      final db = await _dbService.database;
      await db.insert('groups', _currentGroup!.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      for (var m in _currentGroupMembers) {
        await db.insert('group_members', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (var r in _roundRotations) {
        await db.insert('round_rotations', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (var c in _currentGroupContributions) {
        await db.insert('contributions', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      notifyListeners();
    } catch (e) {
      print('Error loading group details: $e');
      _setError('Failed to load group details');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> startGroup(int groupId) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Get group and members
      final data = await _supabaseService.getGroupDetails(groupId);
      final group = PaluwaganGroup.fromMap(data);
      final members = (data['group_members'] as List)
          .map((m) => GroupMember.fromMap(m))
          .toList();

      if (members.length < group.maxMembers) {
        _setError('Group is not yet full');
        return false;
      }

      // 2. Step 5.1: Randomized Rotation
      final List<GroupMember> shuffledMembers = List.from(members)..shuffle();
      
      // 3. Create Round Rotations and Contributions
      final List<Map<String, dynamic>> rotationsData = [];
      final List<Map<String, dynamic>> contributionsData = [];
      
      final startDate = DateTime.now();

      for (int i = 0; i < shuffledMembers.length; i++) {
        final roundNum = i + 1;
        final recipient = shuffledMembers[i];
        final payoutDate = _calculatePayoutDate(startDate, group.frequency, roundNum);

        rotationsData.add({
          'group_id': groupId,
          'round': roundNum,
          'payout_date': payoutDate.toIso8601String(),
          'recipient_id': recipient.userId,
          'recipient_name': recipient.userName,
          'status': roundNum == 1 ? 'in_progress' : 'pending',
        });

        // Create contribution slots for everyone for this round
        for (var member in members) {
          contributionsData.add({
            'group_id': groupId,
            'user_id': member.userId,
            'amount': group.contribution,
            'round': roundNum,
            'status': 'pending',
            'due_date': payoutDate.toIso8601String(),
          });
        }
      }

      // 4. Update Cloud
      await _supabaseService.updateGroupStatus(groupId, 'active');
      await _supabaseService.createRoundRotations(rotationsData);
      await _supabaseService.createContributions(contributionsData);

      // 5. Update local and reload
      await loadGroupDetails(groupId);
      return true;
    } catch (e) {
      _setError('Failed to start group: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendChatMessage(int groupId, String userId, String userName, String message) async {
    try {
      final messageData = {
        'group_id': groupId,
        'user_id': userId,
        'user_name': userName,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _supabaseService.sendChatMessage(messageData);
      
      // Optionally add to local for instant feedback
      _currentGroupChats.add(GroupChat.fromMap(messageData));
      notifyListeners();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<bool> submitPaymentProof({
    required int contributionId,
    required int groupId,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
    required int round,
    required String gcashName,
    required String gcashNumber,
    required String transactionNo,
    required String screenshotPath,
    required double amount,
  }) async {
    _setLoading(true);
    try {
      final proofData = {
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
      };

      await _supabaseService.submitPaymentProof(proofData);
      await loadGroupDetails(groupId);
      return true;
    } catch (e) {
      print('Error submitting payment proof: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyPayment(PaymentProof proof, String verifiedById) async {
    _setLoading(true);
    try {
      // 1. Update proof in Cloud
      await _supabaseService.verifyPayment(proof.id, verifiedById);
      
      // 2. Update contribution status to 'paid'
      await _supabaseService.updateContributionStatus(proof.contributionId, 'paid');

      // 3. Step 5.2: 20% Fee Logic (Calculation logic here)
      // For now we just verify. In a real scenario, we might trigger a transaction record.

      await loadGroupDetails(proof.groupId);
      return true;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rejectPayment(PaymentProof proof, String reason) async {
    _setLoading(true);
    try {
      await _supabaseService.rejectPayment(proof.id, reason);
      await loadGroupDetails(proof.groupId);
      return true;
    } catch (e) {
      print('Error rejecting payment: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<user_model.User?> getUserById(String userId) async {
    return await _supabaseService.getUserById(userId);
  }

  DateTime _calculatePayoutDate(DateTime start, String frequency, int round) {
    switch (frequency.toLowerCase()) {
      case 'weekly': return start.add(Duration(days: 7 * round));
      case 'monthly': return DateTime(start.year, start.month + round, start.day);
      default: return start.add(Duration(days: 30 * round));
    }
  }

  // --- HELPER METHODS ---

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  DateTime _calculateNextPayoutDate(String frequency) {
    final now = DateTime.now();
    switch (frequency.toLowerCase()) {
      case 'weekly': return now.add(const Duration(days: 7));
      case 'monthly': return DateTime(now.year, now.month + 1, now.day);
      default: return now.add(const Duration(days: 30));
    }
  }
}