import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/paluwagan_group.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'group_detail_view.dart';

class AllGroupsPage extends StatelessWidget {
  const AllGroupsPage({super.key, required this.groups});

  final List<PaluwaganGroup> groups;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Paluwagan Groups'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: groups.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: Container(
                  color: Colors.white.withOpacity(0.3),
                  height: 1,
                ),
              )
            : null,
      ),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.group_off,
                      size: 64,
                      color: colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Groups Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create or join a group to get started',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/create-group');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/join-group');
                        },
                        icon: const Icon(Icons.group_add),
                        label: const Text('Join'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final g = groups[index];
                final isCreator = g.createdBy == authVm.currentUser?.id;
                final progress = g.currentRound / g.maxMembers;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Name - Made BIGGER and REMOVED extra text
                        Text(
                          g.name,
                          style: const TextStyle(
                            fontSize: 24, // INCREASED from 20 to 24
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Description - REMOVED the "dsdsd" and "sasas" placeholder text
                        // Now using actual group description from the data
                        Text(
                          g.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Creator/Member Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCreator
                                ? colorScheme.primary.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCreator ? 'Creator' : 'Member',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCreator
                                  ? colorScheme.primary
                                  : Colors.green,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Round ${g.currentRound}/${g.maxMembers}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                colorScheme.primary,
                              ),
                              minHeight: 6,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Stats in 2x2 grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildStat(
                                label: 'Contribution',
                                value:
                                    '₱${g.contribution.toStringAsFixed(0)}',
                              ),
                            ),
                            Expanded(
                              child: _buildStat(
                                label: 'Members',
                                value: '${g.currentMembers}/${g.maxMembers}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStat(
                                label: 'Frequency',
                                value: g.frequency,
                              ),
                            ),
                            Expanded(
                              child: _buildStat(
                                label: 'Next Payout',
                                value: _formatDateShort(g.nextPayoutDate),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Join Code (if creator)
                        if (isCreator) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.key,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Join Code: ${g.joinCode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Code copied to clipboard',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // View Details Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GroupDetailScreen(groupId: g.id),
                                ),
                              );
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStat({required String label, required String value}) {
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
}