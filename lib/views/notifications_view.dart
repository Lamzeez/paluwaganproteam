import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification.dart' as notif_model;
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/groups_viewmodel.dart';
import '../viewmodels/notification_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<void> _markAllAsRead(BuildContext context) async {
    final notifVm = context.read<NotificationViewModel>();
    final success = await notifVm.markAllAsRead();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'All notifications marked as read'
              : (notifVm.errorMessage ?? 'Failed to mark all as read'),
        ),
        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authVm = context.read<AuthViewModel>();
      final notifVm = context.read<NotificationViewModel>();
      final userId = authVm.currentUser?.id;

      if (userId != null) {
        await notifVm.loadUserNotifications(userId);
        await notifVm.startNotificationsStream(userId);
      }
    });
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    notif_model.Notification notification,
  ) async {
    final notifVm = context.read<NotificationViewModel>();
    final groupsVm = context.read<GroupsViewModel>();

    await notifVm.markAsRead(notification.id);

    if (!mounted || notification.groupId == null) {
      return;
    }

    await groupsVm.loadGroupDetails(notification.groupId!);

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamed('/group-detail', arguments: notification.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section - Scaled Down
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Consumer<NotificationViewModel>(
                    builder: (context, notifVm, _) {
                      final canMarkAll = notifVm.notifications.isNotEmpty &&
                          notifVm.unreadCount > 0 &&
                          !notifVm.isLoading;

                      return TextButton(
                        onPressed:
                            canMarkAll ? () => _markAllAsRead(context) : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Mark all as read',
                          style: TextStyle(
                            fontSize: 12,
                            color: canMarkAll
                                ? colorScheme.primary
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: Consumer<NotificationViewModel>(
                builder: (context, notifVm, _) {
                  if (notifVm.isLoading) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 3));
                  }

                  if (notifVm.notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_none_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      final userId =
                          context.read<AuthViewModel>().currentUser?.id;
                      if (userId != null) {
                        await notifVm.loadUserNotifications(userId);
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: notifVm.notifications.length,
                      itemBuilder: (context, index) {
                        final notif = notifVm.notifications[index];
                        return _NotificationTile(
                          notification: notif,
                          onTap: () => _handleNotificationTap(context, notif),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final notif_model.Notification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final date = notification.createdAt;
    final formattedDate = '${date.month}/${date.day}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : const Color(0xFFF1F5F9).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: Border.all(
          color: isUnread ? const Color(0xFFF1F5F9) : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUnread ? const Color(0xFFEEF2FF) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isUnread ? Icons.notifications_active_outlined : Icons.notifications_none_outlined,
            color: isUnread ? const Color(0xFF2563EB) : Colors.grey.shade400,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
            color: isUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              notification.message,
              style: TextStyle(
                fontSize: 12,
                color: isUnread ? const Color(0xFF475569) : Colors.grey.shade500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        onTap: onTap,
        trailing: isUnread
            ? Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final notif_model.Notification notification;

  @override
  Widget build(BuildContext context) {
    final date = notification.createdAt;
    final formattedDate = '${date.month}/${date.day}/${date.year}';
    final formattedTime =
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification',
          style: TextStyle(fontSize: 18, color: Color(0xFF1E293B), fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$formattedDate at $formattedTime',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                Text(
                  notification.message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 24),
                if (notification.groupId != null) ...[
                  _buildDetailRow('Group ID', notification.groupId.toString()),
                  const SizedBox(height: 8),
                ],
                _buildDetailRow('Type', notification.type.replaceAll('_', ' ').toUpperCase()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
