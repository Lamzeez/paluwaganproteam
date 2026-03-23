import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodels/groups_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'home_view.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalPotController = TextEditingController();
  final _contributionController = TextEditingController();
  final _maxMembersController = TextEditingController();

  String _selectedFrequency = 'Monthly';
  final List<String> _frequencies = ['Weekly', 'Monthly'];

  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalPotController.dispose();
    _contributionController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  void _calculateContribution() {
    final totalPot = double.tryParse(_totalPotController.text) ?? 0;
    final maxMembers = int.tryParse(_maxMembersController.text) ?? 0;

    if (totalPot > 0 && maxMembers > 0) {
      _contributionController.text = (totalPot / maxMembers).toStringAsFixed(0);
    }
    setState(() {});
  }

  String _getDeadlineDay() {
    final now = DateTime.now();
    switch (_selectedFrequency.toLowerCase()) {
      case 'weekly':
        return 'Friday';
      case 'monthly':
        final nextMonth = DateTime(now.year, now.month + 1, now.day);
        return '${nextMonth.day}th of next month';
      default:
        return 'TBD';
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final groupsVm = context.read<GroupsViewModel>();
    final authVm = context.read<AuthViewModel>();

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      print('Starting group creation...'); // DEBUG

      final code = await groupsVm.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        totalPot: double.parse(_totalPotController.text),
        contribution: double.parse(_contributionController.text),
        frequency: _selectedFrequency,
        maxMembers: int.parse(_maxMembersController.text),
        createdBy: authVm.currentUser!.id,
        createdByName: authVm.currentUser!.fullName,
      );

      print('Group creation result - Code: $code'); // DEBUG

      setState(() {
        _isCreating = false;
      });

      if (code.isNotEmpty) {
        // Load updated groups for this user
        await groupsVm.loadUserGroups(authVm.currentUser!.id);
        print('Groups reloaded, count: ${groupsVm.groups.length}'); // DEBUG

        if (!mounted) return;

        // Show success dialog with improved navigation
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Group Created Successfully!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Share this code with members to join:',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 24),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code copied!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Navigate directly to dashboard instead of popping multiple times
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          DashboardScreen(user: authVm.currentUser!),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _errorMessage = groupsVm.errorMessage ?? 'Failed to create group';
        });
      }
    } catch (e) {
      print('Error in _createGroup: $e');
      setState(() {
        _isCreating = false;
        _errorMessage = 'An error occurred: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Paluwagan Group',
          style: TextStyle(color: Colors.black), // Black text
        ),
        backgroundColor: Colors.white, // White background
        foregroundColor: Colors.black, // Black icons
        elevation: 0, // Remove shadow
        iconTheme: const IconThemeData(color: Colors.black), // Back icon black
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.group_add,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Start Your Paluwagan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fill in the details to create your group',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Group Name
                _buildField(
                  label: 'Group Name',
                  controller: _nameController,
                  icon: Icons.group,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter group name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description
                _buildField(
                  label: 'Description',
                  controller: _descriptionController,
                  icon: Icons.description,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Total Pot
                _buildField(
                  label: 'Total Pot Amount (₱)',
                  controller: _totalPotController,
                  icon: Icons.account_balance_wallet,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calculateContribution(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter total pot';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter valid amount';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Max Members
                _buildField(
                  label: 'Maximum Members',
                  controller: _maxMembersController,
                  icon: Icons.people,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calculateContribution(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter max members';
                    }
                    final members = int.tryParse(value);
                    if (members == null || members < 2) {
                      return 'Minimum of 2 members';
                    }
                    if (members > 20) {
                      return 'Maximum of 20 members';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Frequency
                DropdownButtonFormField<String>(
                  value: _selectedFrequency,
                  decoration: InputDecoration(
                    labelText: 'Payment Frequency',
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: colorScheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _frequencies.map((frequency) {
                    return DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFrequency = value!;
                    });
                  },
                ),

                const SizedBox(height: 24),

                // Summary Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Pot:',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₱${_totalPotController.text.isEmpty ? '0' : _totalPotController.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Members:',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${_maxMembersController.text.isEmpty ? '0' : _maxMembersController.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Contribution per Group:',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₱${_contributionController.text.isEmpty ? '0' : _contributionController.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Frequency:',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _selectedFrequency,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Payment Deadline:',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _getDeadlineDay(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'CREATE GROUP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    void Function(String)? onChanged,
    double labelFontSize = 14,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: labelFontSize),
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey.shade100 : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16),
      validator: validator,
    );
  }
}
