import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../services/db_service.dart';
import '../models/user.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._dbService);

  final DbService _dbService;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
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

  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'At least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Include at least one special character';
    }
    return null;
  }

  Future<bool> register(User user) async {
    final db = await _dbService.database;

    _setLoading(true);
    _setError(null);

    try {
      final id = await db.insert('users', {
        'full_name': user.fullName,
        'address': user.address,
        'age': user.age,
        'email': user.email.toLowerCase(),
        'password': user.password,
        'id_front_path': user.idFrontPath,
        'id_back_path': user.idBackPath,
        'gcash_name': user.gcashName,
        'gcash_number': user.gcashNumber,
        'urcode_path': user.urcodePath,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      // Set current user after registration
      _currentUser = User(
        id: id,
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

      notifyListeners();
      return true;
    } on DatabaseException catch (e) {
      print('Database error during registration: $e');
      if (e.isUniqueConstraintError()) {
        _setError('Email is already registered.');
      } else {
        _setError('Database error: ${e.toString()}');
      }
      return false;
    } catch (e) {
      print('Error during registration: $e');
      _setError('Registration failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    final db = await _dbService.database;

    _setLoading(true);
    _setError(null);

    try {
      final rows = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email.toLowerCase(), password],
        limit: 1,
      );

      if (rows.isEmpty) {
        _setError('Invalid email or password.');
        _currentUser = null;
        return false;
      }

      final row = rows.first;
      _currentUser = User.fromMap(row);
      notifyListeners();
      return true;
    } catch (_) {
      _setError('Failed to login.');
      _currentUser = null;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
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