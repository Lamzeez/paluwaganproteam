import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/groups_viewmodel.dart';
import '../models/user.dart' as auth_model;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isChangingPassword = false;
  bool _isCheckingDeleteEligibility = false;
  String? _errorMessage;
  String? _successMessage;

  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _gcashNameController = TextEditingController();
  final _gcashNumberController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _newProfilePicture;
  String? _profilePictureFilename;
  String? _newQrPath;
  String? _qrFilename;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      _fullNameController.text = user.fullName;
      _addressController.text = user.address;
      _ageController.text = user.age.toString();
      _gcashNameController.text = user.gcashName ?? '';
      _gcashNumberController.text = user.gcashNumber ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _gcashNameController.dispose();
    _gcashNumberController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        if (type == 'profile') {
          _newProfilePicture = image.path;
          _profilePictureFilename = image.name;
        } else {
          _newQrPath = image.path;
          _qrFilename = image.name;
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    final authVm = context.read<AuthViewModel>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await authVm.updateProfile(
        fullName: _fullNameController.text.trim(),
        address: _addressController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        profilePicture: _newProfilePicture,
        gcashName: _gcashNameController.text.trim(),
        gcashNumber: _gcashNumberController.text.trim(),
        urcodePath: _newQrPath,
      );

      if (success) {
        setState(() {
          _successMessage = 'Profile updated successfully';
          _isEditing = false;
          _newProfilePicture = null;
          _profilePictureFilename = null;
          _newQrPath = null;
          _qrFilename = null;
        });
      } else {
        setState(() {
          _errorMessage = authVm.errorMessage ?? 'Failed to update profile';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'New passwords do not match');
      return;
    }

    final authVm = context.read<AuthViewModel>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final success = await authVm.updatePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    setState(() {
      _isLoading = false;
      if (success) {
        _successMessage = 'Password changed successfully';
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _errorMessage = authVm.errorMessage ?? 'Failed to change password';
      }
    });
  }

  Future<void> _checkDeleteAccountEligibility() async {
    final authVm = context.read<AuthViewModel>();
    final groupsVm = context.read<GroupsViewModel>();

    setState(() {
      _isCheckingDeleteEligibility = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await groupsVm.loadUserGroups(authVm.currentUser!.id);
      final activeGroups = groupsVm.groups.where((g) => g.groupStatus == 'active').toList();
      final canDelete = activeGroups.isEmpty;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            canDelete ? 'Delete Account' : 'Notice',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            canDelete
                ? 'Are you sure you want to permanently delete your account? This action cannot be undone.'
                : 'You cannot delete your account while you are an active member of a group. Please settle all contributions first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CLOSE',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (canDelete)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _performDeleteAccount();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'DELETE',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDeleteEligibility = false;
        });
      }
    }
  }

  Future<void> _performDeleteAccount() async {
    final authVm = context.read<AuthViewModel>();

    setState(() {
      _isCheckingDeleteEligibility = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final success = await authVm.deleteOwnAccount();
    if (!mounted) return;

    setState(() {
      _isCheckingDeleteEligibility = false;
      if (!success) {
        _errorMessage = authVm.errorMessage ?? 'Failed to delete account';
      }
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted successfully.'),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view profile')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              _buildProfileHeader(user, colorScheme),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                _buildMessage(text: _errorMessage!, isError: true),
                const SizedBox(height: 16),
              ],
              if (_successMessage != null) ...[
                _buildMessage(text: _successMessage!, isError: false),
                const SizedBox(height: 16),
              ],
              _buildPersonalSection(user, colorScheme),
              const SizedBox(height: 16),
              _buildAccountSection(user, colorScheme),
              const SizedBox(height: 16),
              _buildGCashSection(user, colorScheme),
              const SizedBox(height: 16),
              if (_isEditing) ...[
                _buildPasswordSection(colorScheme),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 4,
                      shadowColor: colorScheme.primary.withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                _buildActionButtons(colorScheme),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(auth_model.User user, ColorScheme colorScheme) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: ClipOval(
                child: _newProfilePicture != null
                    ? Image.file(File(_newProfilePicture!), fit: BoxFit.cover)
                    : (user.profilePicture != null
                        ? Image.network(
                            user.profilePicture!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildInitials(user.fullName, colorScheme),
                          )
                        : _buildInitials(user.fullName, colorScheme)),
              ),
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _pickImage('profile'),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.fullName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 12, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Member since ${_formatDate(user.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        if (!_isEditing) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('EDIT PROFILE'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isEditing = false;
                _isChangingPassword = false;
                _loadUserData();
              });
            },
            icon: const Icon(Icons.close, size: 14),
            label: const Text('CANCEL EDITING'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              textStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInitials(String name, ColorScheme colorScheme) {
    return Container(
      color: const Color(0xFFEEF2FF),
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMessage({required String text, required bool isError}) {
    final color = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final bgColor = isError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    isError ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection(auth_model.User user, ColorScheme colorScheme) {
    return _buildCard(
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _buildInfoField(
          label: 'Full Name',
          controller: _fullNameController,
          isEditing: _isEditing,
          icon: Icons.badge_outlined,
          value: user.fullName,
        ),
        const SizedBox(height: 12),
        _buildInfoField(
          label: 'Address',
          controller: _addressController,
          isEditing: _isEditing,
          icon: Icons.location_on_outlined,
          value: user.address,
        ),
        const SizedBox(height: 12),
        _buildInfoField(
          label: 'Age',
          controller: _ageController,
          isEditing: _isEditing,
          icon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.number,
          value: user.age.toString(),
        ),
      ],
    );
  }

  Widget _buildAccountSection(auth_model.User user, ColorScheme colorScheme) {
    return _buildCard(
      title: 'Account Information',
      icon: Icons.account_circle_outlined,
      children: [
        _buildReadOnlyField(
          label: 'Email Address',
          value: user.email,
          icon: Icons.email_outlined,
        ),
      ],
    );
  }

  Widget _buildGCashSection(auth_model.User user, ColorScheme colorScheme) {
    return _buildCard(
      title: 'GCash Information',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        _buildInfoField(
          label: 'GCash Name',
          controller: _gcashNameController,
          isEditing: _isEditing,
          icon: Icons.account_box_outlined,
          value: user.gcashName ?? 'Not set',
        ),
        const SizedBox(height: 12),
        _buildInfoField(
          label: 'GCash Number',
          controller: _gcashNumberController,
          isEditing: _isEditing,
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
          value: user.gcashNumber ?? 'Not set',
        ),
        const SizedBox(height: 20),
        const Text(
          'InstaPay QR Code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        _buildQrPreviewCard(imagePath: _newQrPath ?? user.urcodePath),
        if (_isEditing) ...[
          const SizedBox(height: 12),
          _buildUploadButton(
            onTap: () => _pickImage('qr'),
            filename: _qrFilename,
            icon: Icons.qr_code_2_outlined,
            colorScheme: colorScheme,
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordSection(ColorScheme colorScheme) {
    return _buildCard(
      title: 'Security Settings',
      icon: Icons.lock_outline,
      children: [
        if (!_isChangingPassword)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _isChangingPassword = true),
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('CHANGE PASSWORD'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          )
        else ...[
          _buildPasswordField(
            label: 'Current Password',
            controller: _currentPasswordController,
            obscure: _obscureCurrentPassword,
            onToggle: () => setState(
                () => _obscureCurrentPassword = !_obscureCurrentPassword),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'New Password',
            controller: _newPasswordController,
            obscure: _obscureNewPassword,
            onToggle: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: 'Confirm New Password',
            controller: _confirmPasswordController,
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('UPDATE PASSWORD',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('LOGOUT',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              elevation: 4,
              shadowColor: Colors.red.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isCheckingDeleteEligibility
                ? null
                : _checkDeleteAccountEligibility,
            icon: _isCheckingDeleteEligibility
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(
              _isCheckingDeleteEligibility ? 'CHECKING...' : 'DELETE ACCOUNT',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.w900)),
        content:
            const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('CANCEL',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AuthViewModel>().logout();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('LOGOUT',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF94A3B8), size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required IconData icon,
    required String value,
    TextInputType? keyboardType,
  }) {
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 16),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF94A3B8), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(
      {required String label, required String value, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF94A3B8), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.lock_outlined, color: Color(0xFF94A3B8), size: 16),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade400, size: 16),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton({
    required VoidCallback onTap,
    required String? filename,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    final hasFile = filename != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(hasFile ? Icons.check_circle : icon,
                color: hasFile ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasFile ? filename! : 'Tap to upload new QR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasFile ? FontWeight.w700 : FontWeight.w500,
                  color:
                      hasFile ? const Color(0xFF0369A1) : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrPreviewCard({String? imagePath}) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: imagePath != null
            ? (imagePath.startsWith('http')
                ? Image.network(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildQrPlaceholder(),
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildQrPlaceholder(),
                  ))
            : _buildQrPlaceholder(),
      ),
    );
  }

  Widget _buildQrPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_outlined, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 6),
          Text(
            'No QR Code Uploaded',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _getInitials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
