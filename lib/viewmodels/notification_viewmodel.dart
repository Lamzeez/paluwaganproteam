import 'package:flutter/foundation.dart';

import '../services/db_service.dart';
import '../models/notification.dart' as notif_model;

class NotificationViewModel extends ChangeNotifier {
  NotificationViewModel(this._dbService) {
    _loadNotifications();
  }

  final DbService _dbService;

  List<notif_model.Notification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadCount = 0;

  List<notif_model.Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  Future<void> _loadNotifications({String? userId}) async {
    _setLoading(true);
    try {
      final db = await _dbService.database;

      late final List<Map<String, dynamic>> rows;

      if (userId != null) {
        rows = await db.query(
          'notifications',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
        );
      } else {
        rows = await db.query('notifications', orderBy: 'created_at DESC');
      }

      _notifications = rows
          .map((row) => notif_model.Notification.fromMap(row))
          .toList();

      _unreadCount = _notifications.where((n) => !n.isRead).length;
      _setError(null);
    } catch (e) {
      _setError('Failed to load notifications');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    int? groupId,
    Map<String, dynamic>? details,
  }) async {
    final db = await _dbService.database;

    try {
      await db.insert('notifications', {
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'group_id': groupId,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
        'details': details != null
            ? notif_model.Notification.mapToJsonString(details)
            : null,
      });

      await _loadNotifications(userId: userId);
      return true;
    } catch (e) {
      print('Error adding notification: $e');
      return false;
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    final db = await _dbService.database;

    try {
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [notificationId],
      );

      _notifications = _notifications.map((n) {
        if (n.id == notificationId) {
          return notif_model.Notification(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            groupId: n.groupId,
            isRead: true,
            createdAt: n.createdAt,
            details: n.details,
          );
        }
        return n;
      }).toList();

      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(int notificationId) async {
    final db = await _dbService.database;

    try {
      await db.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [notificationId],
      );

      _notifications.removeWhere((n) => n.id == notificationId);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  Future<void> loadUserNotifications(String userId) async {
    await _loadNotifications(userId: userId);
  }
}