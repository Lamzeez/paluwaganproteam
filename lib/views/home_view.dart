import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../models/paluwagan_group.dart';
import '../viewmodels/groups_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/notification_viewmodel.dart';
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
    // Load user groups when dashboard initializes
    _loadUserGroups();
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

  // Get the title for the current screen
  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'PaluwaganPro'; // Show only on Home
      default:
        return ''; // Empty on all other screens
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            fontWeight: FontWeight.normal, // Changed from bold to normal
            color: Colors.black,
          ),
        ),
        // Hide the app bar completely if title is empty
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
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

// Wrapper widgets for screens that need providers or special handling
class NotificationsScreenWrapper extends StatelessWidget {
  const NotificationsScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final notifVm = context.watch<NotificationViewModel>();

    // Load notifications if needed
    if (authVm.currentUser != null && notifVm.notifications.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifVm.loadUserNotifications(authVm.currentUser!.id);
      });
    }

    return const NotificationsScreen();
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

// Extracted Home content from original DashboardScreen
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  void initState() {
    super.initState();
    // Refresh data when home tab is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
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
    final groups = groupsVm.groups;
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate summary stats
    final activeGroups = groups.length;
    final nextPayout = groups.isNotEmpty
        ? groups
              .map((g) => g.nextPayoutDate)
              .reduce((a, b) => a.isBefore(b) ? a : b)
        : null;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildHighlightedSummaryCards(
                context,
                activeGroups,
                groups,
                nextPayout,
                colorScheme,
              ),

              const SizedBox(height: 24),

              // Groups Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Current Group',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  if (groups.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => AllGroupsPage(groups: groups),
                              ),
                            )
                            .then((_) {
                              // Refresh when returning from all groups
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

              // Groups List - Show only ONE group (most recent)
              if (groups.isEmpty)
                _buildEmptyGroupsState(colorScheme)
              else if (groupsVm.isLoading)
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
  }

  // Highlighted Summary Cards
  Widget _buildHighlightedSummaryCards(
    BuildContext context,
    int activeGroups,
    List<PaluwaganGroup> groups,
    DateTime? nextPayout,
    ColorScheme colorScheme,
  ) {
    // Find the group with the nearest payout date
    PaluwaganGroup? nearestGroup;
    if (groups.isNotEmpty && nextPayout != null) {
      nearestGroup = groups.firstWhere(
        (g) => g.nextPayoutDate == nextPayout,
        orElse: () => groups.first,
      );
    }

    return Column(
      children: [
        // Active Groups Card
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

        // Next Payment Card
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
                // Refresh group details when returning
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
              // Group Name - Larger and prominent
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),

              // Description - smaller, grey
              Text(
                group.description,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Status Badge and Round
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: group.status == 'active'
                          ? colorScheme.primary.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      group.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: group.status == 'active'
                            ? colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    'Round ${group.currentRound}/${group.maxMembers}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress Bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                minHeight: 6,
              ),

              const SizedBox(height: 16),

              // Stats Grid - 2x2 layout
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

              // Join Code (if creator)
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
                        onTap: () {
                          // Copy to clipboard
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

              // View Details Button
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
                          // Refresh when returning
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