import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as user_model;
import '../models/paluwagan_group.dart';
import '../models/group_member.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // --- AUTH METHODS ---
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    return await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: type,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  // --- PROFILE METHODS ---
  Future<user_model.User?> getCloudProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return user_model.User.fromMap(response);
  }

  // --- STORAGE METHODS ---
  Future<String> uploadFile({
    required String bucket,
    required String filePath,
    required String remotePath,
  }) async {
    final file = File(filePath);
    await _supabase.storage.from(bucket).upload(
      remotePath,
      file,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );
    return _supabase.storage.from(bucket).getPublicUrl(remotePath);
  }

  // --- GROUP METHODS ---
  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> groupData) async {
    return await _supabase.from('groups').insert(groupData).select().single();
  }

  Future<void> addMember(Map<String, dynamic> memberData) async {
    await _supabase.from('group_members').insert(memberData);
  }

  Future<void> removeMember(int groupId, String userId) async {
    await _supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    // Since creators are added as members, we just need to find groups 
    // where the user is in the group_members table.
    final response = await _supabase
        .from('groups')
        .select('*, group_members!inner(*)')
        .eq('group_members.user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> findGroupByCode(String joinCode) async {
    final response = await _supabase
        .rpc('find_group_by_code', params: {'join_code_param': joinCode});
    
    if (response == null || (response as List).isEmpty) return null;
    return response[0] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGroupDetails(int groupId) async {
    final response = await _supabase
        .from('groups')
        .select('*, group_members(*), round_rotations(*), contributions(*), group_chat(*), payment_proofs(*)')
        .eq('id', groupId)
        .single();
    return response;
  }

  Future<void> updateGroupStatus(int groupId, String status) async {
    await _supabase.from('groups').update({'group_status': status}).eq('id', groupId);
  }

  Future<void> updateGroupRound(int groupId, int round) async {
    await _supabase.from('groups').update({'current_round': round}).eq('id', groupId);
  }

  Future<void> updateGroupMemberCount(int groupId, int count) async {
    await _supabase.from('groups').update({'current_members': count}).eq('id', groupId);
  }

  Future<void> deleteGroup(int groupId) async {
    await _supabase.from('groups').delete().eq('id', groupId);
  }

  Future<void> createRoundRotations(List<Map<String, dynamic>> rotations) async {
    await _supabase.from('round_rotations').insert(rotations);
  }

  Future<void> createContributions(List<Map<String, dynamic>> contributions) async {
    await _supabase.from('contributions').insert(contributions);
  }

  Future<void> sendChatMessage(Map<String, dynamic> messageData) async {
    await _supabase.from('group_chat').insert(messageData);
  }

  Future<void> submitPaymentProof(Map<String, dynamic> proofData) async {
    await _supabase.from('payment_proofs').insert(proofData);
  }

  Future<void> verifyPayment(int proofId, String verifiedById) async {
    await _supabase.from('payment_proofs').update({
      'status': 'verified',
      'verified_at': DateTime.now().toIso8601String(),
      'verified_by_id': verifiedById,
    }).eq('id', proofId);
  }

  Future<void> rejectPayment(int proofId, String reason) async {
    await _supabase.from('payment_proofs').update({
      'status': 'rejected',
      'rejection_reason': reason,
    }).eq('id', proofId);
  }

  Future<void> updateContributionStatus(int contributionId, String status) async {
    await _supabase.from('contributions').update({
      'status': status,
      'paid_at': status == 'paid' ? DateTime.now().toIso8601String() : null,
    }).eq('id', contributionId);
  }

  Future<void> createTransaction(Map<String, dynamic> transactionData) async {
    await _supabase.from('transactions').insert(transactionData);
  }

  Future<void> createTransactions(List<Map<String, dynamic>> transactions) async {
    await _supabase.from('transactions').insert(transactions);
  }

  Future<user_model.User?> getUserById(String userId) async {
    final response = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
    if (response == null) return null;
    return user_model.User.fromMap(response);
  }

  // --- REAL-TIME STREAMS ---
  Stream<List<Map<String, dynamic>>> streamGroups(String userId) {
    return _supabase
        .from('groups')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  Stream<Map<String, dynamic>> streamGroup(int groupId) {
    return _supabase
        .from('groups')
        .stream(primaryKey: ['id'])
        .eq('id', groupId)
        .limit(1)
        .map((data) => data.first);
  }

  Stream<List<Map<String, dynamic>>> streamMembers(int groupId) {
    return _supabase
        .from('group_members')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId);
  }

  Stream<List<Map<String, dynamic>>> streamContributions(int groupId) {
    return _supabase
        .from('contributions')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId);
  }

  Stream<List<Map<String, dynamic>>> streamRotations(int groupId) {
    return _supabase
        .from('round_rotations')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId);
  }

  Stream<List<Map<String, dynamic>>> streamPaymentProofs(int groupId) {
    return _supabase
        .from('payment_proofs')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId);
  }

  Stream<List<Map<String, dynamic>>> streamChat(int groupId) {
    return _supabase
        .from('group_chat')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('timestamp');
  }
}