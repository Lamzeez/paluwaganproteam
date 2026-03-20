import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../viewmodels/auth_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // For password change
  bool _isChangingPassword = false;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Controllers for editable fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _gcashNameController = TextEditingController();
  final TextEditingController _gcashNumberController = TextEditingController();

  // InstaPay QR Code
  String? _newQrPath;
  String? _qrFilename;

  // Profile picture
  String? _newProfilePicture;
  String? _profilePictureFilename;

  final ImagePicker _picker = ImagePicker();

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
      _qrFilename = user.urcodePath != null ? 'Current InstaPay QR Code' : null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
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

  Future<void> _pickImage(String imageType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          if (imageType == 'profile') {
            _newProfilePicture = image.path;
            _profilePictureFilename = image.name;
          } else if (imageType == 'qr') {
            _newQrPath = image.path;
            _qrFilename = image.name;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_isEditing) return;

    // Validate age
    final ageText = _ageController.text.trim();
    if (ageText.isNotEmpty) {
      final age = int.tryParse(ageText);
      if (age == null || age <= 0) {
        setState(() {
          _errorMessage = 'Please enter a valid age';
        });
        return;
      }
      if (age < 18) {
        setState(() {
          _errorMessage = 'You must be at least 18 years old';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authVm = context.read<AuthViewModel>();

    final success = await authVm.updateProfile(
      fullName: _fullNameController.text.trim().isNotEmpty
          ? _fullNameController.text.trim()
          : null,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      age: _ageController.text.trim().isNotEmpty
          ? int.parse(_ageController.text.trim())
          : null,
      profilePicture: _newProfilePicture,
      gcashName: _gcashNameController.text.trim().isNotEmpty
          ? _gcashNameController.text.trim()
          : null,
      gcashNumber: _gcashNumberController.text.trim().isNotEmpty
          ? _gcashNumberController.text.trim()
          : null,
      urcodePath: _newQrPath,
    );

    setState(() {
      _isLoading = false;
      if (success) {
        _successMessage = 'Profile updated successfully!';
        _isEditing = false;
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _newProfilePicture = null;
        _profilePictureFilename = null;
        _newQrPath = null;
        _loadUserData();
      } else {
        _errorMessage = authVm.errorMessage ?? 'Failed to update profile';
      }
    });

    if (success) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    }
  }

  Future<void> _changePassword() async {
    // Check if all fields are filled
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all password fields';
      });
      return;
    }

    // Check if new password and confirm password match
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'New password and confirm password do not match';
      });
      return;
    }

    final authVm = context.read<AuthViewModel>();
    final user = authVm.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage = 'User not found';
      });
      return;
    }

    // Check if current password is correct
    if (_currentPasswordController.text != user.password) {
      setState(() {
        _errorMessage = 'Current password is incorrect';
      });
      return;
    }

    // Check if new password is same as current password
    if (_newPasswordController.text == user.password) {
      setState(() {
        _errorMessage = 'New password must be different from current password';
      });
      return;
    }

    // Validate password strength (same regex as signup)
    final passwordError = AuthViewModel.validateStrongPassword(
      _newPasswordController.text,
    );
    if (passwordError != null) {
      setState(() {
        _errorMessage = passwordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await authVm.updatePassword(_newPasswordController.text);

    setState(() {
      _isLoading = false;
      if (success) {
        _successMessage = 'Password updated successfully!';
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _isChangingPassword = false;
      } else {
        _errorMessage = 'Failed to update password';
      }
    });

    if (success) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please log in to view profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, size: 24, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 24, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _isChangingPassword = false;
                  _newProfilePicture = null;
                  _profilePictureFilename = null;
                  _newQrPath = null;
                  _errorMessage = null;
                  _fullNameController.text = user.fullName;
                  _addressController.text = user.address;
                  _ageController.text = user.age.toString();
                  _gcashNameController.text = user.gcashName ?? '';
                  _gcashNumberController.text = user.gcashNumber ?? '';
                  _currentPasswordController.clear();
                  _newPasswordController.clear();
                  _confirmPasswordController.clear();
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture Section
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _newProfilePicture != null
                        ? FileImage(File(_newProfilePicture!))
                        : (user.profilePicture != null
                              ? FileImage(File(user.profilePicture!))
                              : null),
                    child:
                        user.profilePicture == null &&
                            _newProfilePicture == null
                        ? Text(
                            _getInitials(user.fullName),
                            style: TextStyle(
                              fontSize: 28,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.normal,
                            ),
                          )
                        : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _pickImage('profile'),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_isEditing && _profilePictureFilename != null) ...[
              const SizedBox(height: 8),
              Text(
                'New: $_profilePictureFilename',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Messages
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Personal Information Section
            _buildSection(
              context: context,
              title: 'Personal Information',
              icon: Icons.person_outline,
              iconColor: Colors.black54,
              children: [
                _buildInfoField(
                  context: context,
                  label: 'Full Name',
                  value: user.fullName,
                  controller: _fullNameController,
                  isEditing: _isEditing,
                  textColor: Colors.black87,
                ),
                const SizedBox(height: 16),
                _buildInfoField(
                  context: context,
                  label: 'Address',
                  value: user.address,
                  controller: _addressController,
                  isEditing: _isEditing,
                  textColor: Colors.black87,
                ),
                const SizedBox(height: 16),
                _buildInfoField(
                  context: context,
                  label: 'Age',
                  value: '${user.age}',
                  controller: _ageController,
                  isEditing: _isEditing,
                  keyboardType: TextInputType.number,
                  textColor: Colors.black87,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Email Section
            _buildSection(
              context: context,
              title: 'Account Information',
              icon: Icons.email_outlined,
              iconColor: Colors.black54,
              children: [
                _buildReadOnlyField(
                  context: context,
                  label: 'Email',
                  value: user.email,
                  icon: Icons.email_outlined,
                  iconColor: Colors.black54,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // GCash Information Section
            _buildSection(
              context: context,
              title: 'GCash Information',
              icon: Icons.payment_outlined,
              iconColor: Colors.black54,
              children: [
                _buildInfoField(
                  context: context,
                  label: 'GCash Name',
                  value: user.gcashName ?? 'Not set',
                  controller: _gcashNameController,
                  isEditing: _isEditing,
                  textColor: Colors.black87,
                ),
                const SizedBox(height: 16),
                _buildInfoField(
                  context: context,
                  label: 'GCash Number',
                  value: user.gcashNumber ?? 'Not set',
                  controller: _gcashNumberController,
                  isEditing: _isEditing,
                  keyboardType: TextInputType.phone,
                  textColor: Colors.black87,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 16),
                  // InstaPay QR Code Upload
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'InstaPay QR Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _pickImage('qr'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('Choose File'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _qrFilename != null
                                    ? Text(
                                        _qrFilename!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Text(
                                        user.urcodePath != null ? 'Current InstaPay QR Code' : 'No InstaPay QR Code',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: user.urcodePath != null ? Colors.black87 : Colors.grey,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Password Change Section (only when editing)
            if (_isEditing) ...[
              _buildSection(
                context: context,
                title: 'Change Password',
                icon: Icons.lock_outline,
                iconColor: Colors.black54,
                children: [
                  if (!_isChangingPassword)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isChangingPassword = true;
                          });
                        },
                        icon: const Icon(Icons.lock_reset, size: 20, color: Colors.black54),
                        label: const Text(
                          'Change Password',
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                    )
                  else ...[
                    // Current Password - with border
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrentPassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your current password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureCurrentPassword =
                                      !_obscureCurrentPassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // New Password - with border
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            hintText: 'Enter new password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password - with border
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confirm Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: 'Confirm new password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Update Password Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
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
                                'UPDATE PASSWORD',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Save Button (only when editing)
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

            // Logout Button
            if (!_isEditing) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Logout',
                          style: TextStyle(fontSize: 18),
                        ),
                        content: const Text(
                          'Are you sure you want to logout?',
                          style: TextStyle(fontSize: 15),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 15, color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              context.read<AuthViewModel>().logout();
                              Navigator.of(
                                context,
                              ).pushReplacementNamed('/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(fontSize: 15, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, size: 20, color: Colors.white),
                  label: const Text(
                    'LOGOUT',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditing,
    TextInputType? keyboardType,
    int maxLines = 1,
    Color textColor = Colors.black87,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.normal,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your $label',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}