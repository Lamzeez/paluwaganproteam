import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/groups_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'home_view.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a join code');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final groupsVm = context.read<GroupsViewModel>();
      final authVm = context.read<AuthViewModel>();

      print('Attempting to join group with code: $code'); // DEBUG

      final success = await groupsVm.joinGroup(
        code,
        authVm.currentUser!.id,
        authVm.currentUser!.fullName,
      );

      print('Join group result: $success'); // DEBUG

      // IMPORTANT: Load user's groups immediately after joining
      if (success && authVm.currentUser != null) {
        await groupsVm.loadUserGroups(authVm.currentUser!.id);
        print(
          'Groups reloaded after join, count: ${groupsVm.groups.length}',
        ); // DEBUG
      }

      setState(() => _isJoining = false);

      if (!mounted) return;

      if (success) {
        // Show success dialog then go back to home
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
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Successfully Joined!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'You are now a member of the group.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Navigate directly to dashboard
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
          _errorMessage = groupsVm.errorMessage ?? 'Failed to join group';
        });
      }
    } catch (e) {
      print('Error in _joinGroup: $e');
      setState(() {
        _isJoining = false;
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
          'Join Paluwagan Group',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      'Join a Group',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the join code provided by the group creator',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

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

              // Join Code Input
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Enter 6-digit Code',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      onEditingComplete: _joinGroup,
                    ),

                    const SizedBox(height: 24),

                    // Join Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isJoining ? null : _joinGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isJoining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'JOIN GROUP',
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

              const SizedBox(height: 24),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How to get a join code?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ask the group creator for the 6-digit code or check your invitation message.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}