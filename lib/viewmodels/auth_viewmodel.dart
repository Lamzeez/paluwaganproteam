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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  // Registration with Supabase and SQLite Sync
  Future<bool> register(User user) async {
    _setLoading(true);
    _setError(null);

    try {
      // 1. Sign up with Supabase Auth
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

      // 2. Upload files to Supabase Storage
      String idFrontUrl = user.idFrontPath;
      String idBackUrl = user.idBackPath;
      String? urcodeUrl = user.urcodePath;

      try {
        if (user.idFrontPath.isNotEmpty && !user.idFrontPath.startsWith('http')) {
          idFrontUrl = await _supabaseService.uploadFile(
            bucket: 'profiles',
            filePath: user.idFrontPath,
            remotePath: '$cloudId/id_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }

        if (user.idBackPath.isNotEmpty && !user.idBackPath.startsWith('http')) {
          idBackUrl = await _supabaseService.uploadFile(
            bucket: 'profiles',
            filePath: user.idBackPath,
            remotePath: '$cloudId/id_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }

        if (user.urcodePath != null && user.urcodePath!.isNotEmpty && !user.urcodePath!.startsWith('http')) {
          urcodeUrl = await _supabaseService.uploadFile(
            bucket: 'profiles',
            filePath: user.urcodePath!,
            remotePath: '$cloudId/urcode_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      } catch (e) {
        print('Warning: File upload failed, continuing with local paths: $e');
      }

      // 3. Create Cloud Profile in 'profiles' table
      final profileData = {
        'id': cloudId,
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

      await _supabaseService.createCloudProfile(profileData);

      // 4. Save to local SQLite for offline support
      final db = await _dbService.database;
      await db.insert('users', {
        ...profileData,
        'password': user.password,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      _isWaitingForEmailVerification = true;
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
      final response = await _supabaseService.verifyOTP(
        email: email,
        token: token,
        type: supabase.OtpType.signup,
      );

      if (response.user != null) {
        // Verification successful, fetch profile and set currentUser
        final cloudId = response.user!.id;
        final cloudUser = await _supabaseService.getCloudProfile(cloudId);
        
        if (cloudUser != null) {
          _currentUser = cloudUser;
        } else {
          // Fallback to local if profile table is still syncing
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
  Future<bool> updatePassword(String newPassword) async {
    if (_currentUser == null) return false;

    final db = await _dbService.database;

    _setLoading(true);
    _setError(null);

    try {
      await db.update(
        'users',
        {'password': newPassword},
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      // Update current user's password
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
    String? bio,
    String? phoneNumber,
    String? profilePicture,
    String? gcashName,
    String? gcashNumber,
    String? urcodePath,
  }) async {
    if (_currentUser == null) return false;

    final db = await _dbService.database;
    final updates = <String, dynamic>{};

    if (fullName != null) updates['full_name'] = fullName;
    if (address != null) updates['address'] = address;
    if (age != null) updates['age'] = age;
    if (bio != null) updates['bio'] = bio;
    if (phoneNumber != null) updates['phone_number'] = phoneNumber;
    if (profilePicture != null) updates['profile_picture'] = profilePicture;
    if (gcashName != null) updates['gcash_name'] = gcashName;
    if (gcashNumber != null) updates['gcash_number'] = gcashNumber;
    if (urcodePath != null) updates['urcode_path'] = urcodePath;

    if (updates.isEmpty) return true;

    try {
      await db.update(
        'users',
        updates,
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      // Refresh current user
      final rows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        _currentUser = User.fromMap(rows.first);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}