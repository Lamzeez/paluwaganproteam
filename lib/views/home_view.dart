import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../models/paluwagan_group.dart';
import '../viewmodels/groups_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/notification_viewmodel.dart';
import '../services/quote_service.dart';
import 'group_detail_view.dart';
import 'profile_view.dart';
import 'notifications_view.dart';
import 'all_groups_view.dart';
import 'create_group_view.dart';
import 'join_group_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user});

  final User user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNotifications();
      _loadUserGroups();
    });
  }

  Future<void> _startNotifications() async {
    final authVm = context.read<AuthViewModel>();
    final notifVm = context.read<NotificationViewModel>();

    if (authVm.currentUser != null &&
        notifVm.activeUserId != authVm.currentUser!.id) {
      await notifVm.loadUserNotifications(authVm.currentUser!.id);
      await notifVm.startNotificationsStream(authVm.currentUser!.id);
    }
  }

  Future<void> _loadUserGroups() async {
    final groupsVm = context.read<GroupsViewModel>();
    final authVm = context.read<AuthViewModel>();

    if (authVm.currentUser != null) {
      await groupsVm.loadUserGroups(authVm.currentUser!.id);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'PaluwaganPro';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifVm = context.watch<NotificationViewModel>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: Colors.black,
          ),
        ),
        toolbarHeight: _getAppBarTitle().isEmpty ? 0 : kToolbarHeight,
      ),
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _NotificationNavIcon(
              icon: Icons.notifications_outlined,
              unreadCount: notifVm.unreadCount,
            ),
            activeIcon: _NotificationNavIcon(
              icon: Icons.notifications,
              unreadCount: notifVm.unreadCount,
            ),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_add_outlined),
            activeIcon: Icon(Icons.group_add),
            label: 'Join',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return const HomeContent();
      case 1:
        return const NotificationsScreenWrapper();
      case 2:
        return const CreateGroupScreenWrapper();
      case 3:
        return const JoinGroupScreenWrapper();
      case 4:
        return const ProfileScreenWrapper();
      default:
        return const HomeContent();
    }
  }
}

class NotificationsScreenWrapper extends StatelessWidget {
  const NotificationsScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotificationsScreen();
  }
}

class _NotificationNavIcon extends StatelessWidget {
  const _NotificationNavIcon({required this.icon, required this.unreadCount});

  final IconData icon;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (unreadCount > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CreateGroupScreenWrapper extends StatelessWidget {
  const CreateGroupScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateGroupScreen();
  }
}

class JoinGroupScreenWrapper extends StatelessWidget {
  const JoinGroupScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const JoinGroupScreen();
  }
}

class ProfileScreenWrapper extends StatelessWidget {
  const ProfileScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String _quote = "Loading daily motivation...";
  final _quoteService = QuoteService();

  @override
  void initState() {
    super.initState();
    _fetchQuote();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _fetchQuote() async {
    final q = await _quoteService.getRandomQuote();
    if (mounted) {
      setState(() {
        _quote = q;
      });
    }
  }

  Future<void> _refreshData() async {
    final groupsVm = context.read<GroupsViewModel>();
    final authVm = context.read<AuthViewModel>();
    final notifVm = context.read<NotificationViewModel>();

    if (authVm.currentUser != null) {
      await groupsVm.loadUserGroups(authVm.currentUser!.id);
      await notifVm.loadUserNotifications(authVm.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsVm = context.watch<GroupsViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: groupsVm.streamGroups(authVm.currentUser!.id),
      builder: (context, snapshot) {
        final groups =
            snapshot.data?.map((g) => PaluwaganGroup.fromMap(g)).toList() ??
            groupsVm.groups;

        final activeGroups = groups.length;
        final nextPayout = groups.isNotEmpty
            ? groups
                  .map((g) => g.nextPayoutDate)
                  .reduce((a, b) => a.isBefore(b) ? a : b)
            : null;

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _fetchQuote();
              await _refreshData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuoteCard(colorScheme),
                  const SizedBox(height: 16),
                  _buildHighlightedSummaryCards(
                    context,
                    activeGroups,
                    groups,
                    nextPayout,
                    colorScheme,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Current Group',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (groups.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => const AllGroupsPage(),
                                  ),
                                )
                                .then((_) {
                                  _refreshData();
                                });
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    _buildEmptyGroupsState(colorScheme)
                  else if (groupsVm.isLoading && groups.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: groups
                          .take(1)
                          .map((g) => _buildGroupCard(context, g, colorScheme))
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuoteCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote, color: colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Daily Motivation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _quote,
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedSummaryCards(
    BuildContext context,
    int activeGroups,
    List<PaluwaganGroup> groups,
    DateTime? nextPayout,
    ColorScheme colorScheme,
  ) {
    PaluwaganGroup? nearestGroup;

    // Only show next payment for groups that have actually started (active status)
    final startedGroups = groups
        .where((g) => g.groupStatus == 'active')
        .toList();

    if (startedGroups.isNotEmpty) {
      // Find the group with the earliest payout date among started groups
      final minDate = startedGroups
          .map((g) => g.nextPayoutDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      nearestGroup = startedGroups.firstWhere(
        (g) => g.nextPayoutDate == minDate,
        orElse: () => startedGroups.first,
      );

      // Update nextPayout to use the date from started groups
      nextPayout = minDate;
    } else {
      nearestGroup = null;
      nextPayout = null;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Groups',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeGroups.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Total groups',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B5CF6),
                const Color(0xFF8B5CF6).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Next Payment',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (nearestGroup != null) ...[
                Text(
                  nearestGroup.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateWithYear(nextPayout!),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDaysUntil(nextPayout),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                const Text(
                  'No upcoming payments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyGroupsState(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_off,
              size: 48,
              color: colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Groups Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new group or join an existing one to start your paluwagan journey!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    PaluwaganGroup group,
    ColorScheme colorScheme,
  ) {
    final progress = group.currentRound / group.maxMembers;
    final authVm = context.read<AuthViewModel>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(groupId: group.id),
                ),
              )
              .then((_) {
                _refreshData();
              });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                group.description,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                    ),
                    child: Text(
                      group.groupStatus == 'active'
                          ? 'Active'
                          : (group.groupStatus == 'completed'
                                ? 'Completed'
                                : 'Pending'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: group.groupStatus == 'active'
                            ? colorScheme.primary
                            : (group.groupStatus == 'completed'
                                  ? Colors.green
                                  : Colors.grey),
                      ),
                    ),
                  ),
                  Text(
                    group.groupStatus == 'pending'
                        ? 'Waiting to Start'
                        : 'Round ${group.currentRound}/${group.maxMembers}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                minHeight: 6,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildGroupStat(
                      label: 'Contribution',
                      value: '₱${group.contribution.toStringAsFixed(0)}',
                    ),
                  ),
                  Expanded(
                    child: _buildGroupStat(
                      label: 'Members',
                      value: '${group.currentMembers}/${group.maxMembers}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildGroupStat(
                      label: 'Frequency',
                      value: group.frequency,
                    ),
                  ),
                  Expanded(
                    child: _buildGroupStat(
                      label: 'Next Payout',
                      value: _formatDateShort(group.nextPayoutDate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (group.createdBy == authVm.currentUser?.id)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.key, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Join Code: ${group.joinCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: group.joinCode),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code copied to clipboard'),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.copy,
                          size: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GroupDetailScreen(groupId: group.id),
                          ),
                        )
                        .then((_) {
                          _refreshData();
                        });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'VIEW DETAILS',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _formatDateWithYear(DateTime date) {
    return '${date.month} ${_getMonthName(date.month)} ${date.year}';
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

  String _getDaysUntil(DateTime date) {
    final days = date.difference(DateTime.now()).inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '$days days left';
  }
}
