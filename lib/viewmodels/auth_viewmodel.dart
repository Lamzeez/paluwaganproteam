import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../services/db_service.dart';
import '../services/supabase_service.dart';
import '../models/user.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._dbService, this._supabaseService);

  final DbService _dbService;
  final SupabaseService _supabaseService;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isWaitingForEmailVerification = false;
  DateTime? _lastVerificationEmailSentAt;

  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isWaitingForEmailVerification => _isWaitingForEmailVerification;
  DateTime? get lastVerificationEmailSentAt => _lastVerificationEmailSentAt;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  User? _pendingUser;

  // Registration with Supabase and SQLite Sync
  Future<bool> register(User user) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Sign up with Supabase Auth
      // This will trigger the DB function to create a basic profile row
      final response = await _supabaseService.signUp(
        email: user.email,
        password: user.password,
        metadata: {
          'full_name': user.fullName,
          'address': user.address,
          'age': user.age,
        },
      );

      if (response.user == null) {
        _setError('Registration failed');
        return false;
      }

      final cloudId = response.user!.id;
      
      // Store user data locally so we can complete it after verification
      _pendingUser = User(
        id: cloudId,
        fullName: user.fullName,
        address: user.address,
        age: user.age,
        email: user.email,
        password: user.password,
        idFrontPath: user.idFrontPath,
        idBackPath: user.idBackPath,
        gcashName: user.gcashName,
        gcashNumber: user.gcashNumber,
        urcodePath: user.urcodePath,
        createdAt: DateTime.now(),
      );

      // Save to local SQLite immediately for backup
      final db = await _dbService.database;
      await db.insert('users', {
        ..._pendingUser!.toMap(),
        'password': user.password,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      _isWaitingForEmailVerification = true;
      _lastVerificationEmailSentAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      print('Error during registration: $e');
      _setError('Registration failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyEmailOTP(String email, String token) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Verify the OTP
      final response = await _supabaseService.verifyOTP(
        email: email,
        token: token,
        type: supabase.OtpType.signup,
      );

      if (response.user != null) {
        final cloudId = response.user!.id;

        // 2. NOW that we are authenticated, complete the profile
        if (_pendingUser != null && _pendingUser!.id == cloudId) {
          await _completeRegistration(_pendingUser!);
          _pendingUser = null;
        }

        // 3. Fetch final profile
        final cloudUser = await _supabaseService.getCloudProfile(cloudId);
        
        if (cloudUser != null) {
          _currentUser = cloudUser;
        } else {
          final db = await _dbService.database;
          final rows = await db.query('users', where: 'id = ?', whereArgs: [cloudId]);
          if (rows.isNotEmpty) {
            _currentUser = User.fromMap(rows.first);
          }
        }
        
        _isWaitingForEmailVerification = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Verification failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendEmailOTP(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _supabaseService.resendSignupOTP(email: email);
      _lastVerificationEmailSentAt = DateTime.now();
      notifyListeners();
      return true;
    } on supabase.AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to resend verification code');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Private helper to handle file uploads and profile completion
  Future<void> _completeRegistration(User user) async {
    String idFrontUrl = user.idFrontPath;
    String idBackUrl = user.idBackPath;
    String? urcodeUrl = user.urcodePath;

    try {
      // These will now work because we have an active session!
      if (user.idFrontPath.isNotEmpty && !user.idFrontPath.startsWith('http')) {
        idFrontUrl = await _supabaseService.uploadFile(
          bucket: 'profiles',
          filePath: user.idFrontPath,
          remotePath: '${user.id}/id_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      if (user.idBackPath.isNotEmpty && !user.idBackPath.startsWith('http')) {
        idBackUrl = await _supabaseService.uploadFile(
          bucket: 'profiles',
          filePath: user.idBackPath,
          remotePath: '${user.id}/id_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      if (user.urcodePath != null && user.urcodePath!.isNotEmpty && !user.urcodePath!.startsWith('http')) {
        urcodeUrl = await _supabaseService.uploadFile(
          bucket: 'profiles',
          filePath: user.urcodePath!,
          remotePath: '${user.id}/urcode_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      // Update the cloud profile with the uploaded URLs and GCash info
      final profileData = {
        'id': user.id,
        'full_name': user.fullName,
        'address': user.address,
        'age': user.age,
        'email': user.email.toLowerCase(),
        'id_front_path': idFrontUrl,
        'id_back_path': idBackUrl,
        'gcash_name': user.gcashName,
        'gcash_number': user.gcashNumber,
        'urcode_path': urcodeUrl,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.updateCloudProfile(profileData);
      
      // Update local SQLite with the new URLs
      final db = await _dbService.database;
      await db.update('users', profileData, where: 'id = ?', whereArgs: [user.id]);
    } catch (e) {
      print('Error completing profile: $e');
      // We don't throw here to allow the user to at least log in, 
      // they can finish their profile later in the Profile view if needed.
    }
  }

  // Login with Supabase and Sync to Local
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Sign in with Supabase
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _setError('Invalid email or password');
        return false;
      }

      final cloudId = response.user!.id;

      // 2. Fetch full profile from cloud
      final cloudUser = await _supabaseService.getCloudProfile(cloudId);
      
      if (cloudUser != null) {
        _currentUser = cloudUser;
        
        // 3. Sync to local SQLite
        final db = await _dbService.database;
        await db.insert('users', {
          ...cloudUser.toMap(),
          'password': password, // Store password locally for offline login fallback
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        // Fallback to local if profile table missing (shouldn't happen)
        final db = await _dbService.database;
        final rows = await db.query('users', where: 'id = ?', whereArgs: [cloudId]);
        if (rows.isNotEmpty) {
          _currentUser = User.fromMap(rows.first);
        }
      }

      notifyListeners();
      return true;
    } on supabase.AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Login failed');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() async {
    await _supabaseService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // Update password method
  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) return false;

    final db = await _dbService.database;

    _setLoading(true);
    _setError(null);

    try {
      await _supabaseService.signIn(
        email: _currentUser!.email,
        password: currentPassword,
      );

      await _supabaseService.updateAuthPassword(newPassword: newPassword);

      await db.update(
        'users',
        {'password': newPassword},
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      _currentUser = User(
        id: _currentUser!.id,
        fullName: _currentUser!.fullName,
        address: _currentUser!.address,
        age: _currentUser!.age,
        email: _currentUser!.email,
        password: newPassword,
        idFrontPath: _currentUser!.idFrontPath,
        idBackPath: _currentUser!.idBackPath,
        profilePicture: _currentUser!.profilePicture,
        bio: _currentUser!.bio,
        phoneNumber: _currentUser!.phoneNumber,
        gcashName: _currentUser!.gcashName,
        gcashNumber: _currentUser!.gcashNumber,
        urcodePath: _currentUser!.urcodePath,
        createdAt: _currentUser!.createdAt,
      );

      notifyListeners();
      return true;
    } on supabase.AuthException catch (e) {
      final normalizedMessage = e.message.toLowerCase();
      if (normalizedMessage.contains('invalid login credentials')) {
        _setError('Incorrect current password');
      } else {
        _setError(e.message);
      }
      return false;
    } catch (e) {
      _setError('Failed to update password');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? address,
    int? age,
    String? profilePicture,
    String? gcashName,
    String? gcashNumber,
    String? urcodePath,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _setError(null);

    try {
      String? profilePictureUrl = profilePicture;
      String? urcodeUrl = urcodePath;

      // 1. Upload new files if they are local paths
      if (profilePicture != null && !profilePicture.startsWith('http')) {
        profilePictureUrl = await _supabaseService.uploadFile(
          bucket: 'profiles',
          filePath: profilePicture,
          remotePath: '${_currentUser!.id}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      if (urcodePath != null && !urcodePath.startsWith('http')) {
        urcodeUrl = await _supabaseService.uploadFile(
          bucket: 'profiles',
          filePath: urcodePath,
          remotePath: '${_currentUser!.id}/urcode_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      // 2. Prepare updates for Cloud
      final updates = <String, dynamic>{
        'id': _currentUser!.id,
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (address != null) updates['address'] = address;
      if (age != null) updates['age'] = age;
      if (profilePictureUrl != null) updates['profile_picture'] = profilePictureUrl;
      if (gcashName != null) updates['gcash_name'] = gcashName;
      if (gcashNumber != null) updates['gcash_number'] = gcashNumber;
      if (urcodeUrl != null) updates['urcode_path'] = urcodeUrl;

      // 3. Update Supabase
      await _supabaseService.updateCloudProfile(updates);

      // 4. Update local SQLite
      final db = await _dbService.database;
      await db.update(
        'users',
        updates,
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      // 5. Refresh current user state
      final cloudUser = await _supabaseService.getCloudProfile(_currentUser!.id);
      if (cloudUser != null) {
        _currentUser = cloudUser;
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
