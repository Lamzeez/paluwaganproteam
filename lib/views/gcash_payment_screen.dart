import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/paluwagan_group.dart';
import '../models/contribution.dart';
import '../models/group_member.dart';
import '../viewmodels/groups_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';

class GcashPaymentScreen extends StatefulWidget {
  const GcashPaymentScreen({
    super.key,
    required this.group,
    required this.contribution,
    required this.round,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
  });

  final PaluwaganGroup group;
  final Contribution contribution;
  final int round;
  final String recipientId;
  final String recipientName;
  final double amount;

  @override
  State<GcashPaymentScreen> createState() => _GcashPaymentScreenState();
}

class _GcashPaymentScreenState extends State<GcashPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gcashNameController = TextEditingController();
  final _gcashNumberController = TextEditingController();
  final _transactionNoController = TextEditingController();

  String? recipientGcashName;
  String? recipientGcashNumber;
  String? recipientQrPath;

  String? _screenshotPath;
  String? _screenshotFilename;
  bool _isSubmitting = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Load recipient's actual profile data (GCash info and QR code)
    _loadRecipientInfo();
  }

  Future<void> _loadRecipientInfo() async {
    try {
      final groupsVm = context.read<GroupsViewModel>();
      // Use the new method to get user by ID
      final user = await groupsVm.getUserById(widget.recipientId);

      setState(() {
        recipientGcashName = user?.fullName ?? widget.recipientName;
        recipientGcashNumber = user?.gcashNumber ?? '';
        recipientQrPath = user?.urcodePath ?? '';
      });
    } catch (e) {
      print('Error loading recipient info: $e');
      setState(() {
        recipientGcashName = widget.recipientName;
        recipientGcashNumber = '';
        recipientQrPath = '';
      });
    }
  }

  @override
  void dispose() {
    _gcashNameController.dispose();
    _gcashNumberController.dispose();
    _transactionNoController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _screenshotPath = image.path;
          _screenshotFilename = image.name;
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

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_screenshotPath == null) {
      setState(() {
        _errorMessage = 'Please upload transaction screenshot';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final groupsVm = context.read<GroupsViewModel>();
    final authVm = context.read<AuthViewModel>();

    final success = await groupsVm.submitPaymentProof(
      groupId: widget.group.id,
      contributionId: widget.contribution.id,
      senderId: authVm.currentUser!.id,
      senderName: authVm.currentUser!.fullName,
      recipientId: widget.recipientId,
      recipientName: widget.recipientName,
      round: widget.round,
      gcashName: _gcashNameController.text.trim(),
      gcashNumber: _gcashNumberController.text.trim(),
      transactionNo: _transactionNoController.text.trim(),
      screenshotPath: _screenshotPath!,
      amount: widget.amount,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Payment Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your payment for Round ${widget.round} has been submitted and is pending verification by ${widget.recipientName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to group detail
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _errorMessage = groupsVm.errorMessage ?? 'Failed to submit payment';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pay Round ${widget.round}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipient Info Card - UPDATED to match the picture
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send GCash Payment To:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        recipientGcashName ?? widget.recipientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipientGcashNumber ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (recipientQrPath != null &&
                                recipientQrPath!.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('GCash QR Code'),
                                  content: Image.file(File(recipientQrPath!)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('QR code not available'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('VIEW QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Your GCash Information Section - UPDATED to match the picture
              const Text(
                'Your GCash Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // GCash Name field with hint
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 8, right: 12),
                      child: Text(
                        'GCash Name',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    TextFormField(
                      controller: _gcashNameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your GCash name',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter GCash name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // GCash Number field with hint
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 8, right: 12),
                      child: Text(
                        'GCash Number',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    TextFormField(
                      controller: _gcashNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Enter your GCash number',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter GCash number';
                        }
                        if (value.trim().length < 11) {
                          return 'Please enter a valid GCash number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Transaction Reference Section
              const Text(
                'Transaction Reference',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Transaction Reference field
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 8, right: 12),
                      child: Text(
                        'Transaction Reference No.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    TextFormField(
                      controller: _transactionNoController,
                      decoration: const InputDecoration(
                        hintText: 'Enter transaction reference number',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter transaction reference';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Upload Transaction Proof Section
              const Text(
                'Upload Transaction Proof',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Screenshot Upload Area
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_screenshotPath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_screenshotPath!),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _screenshotFilename ?? 'Screenshot selected',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickScreenshot,
                        icon: const Icon(Icons.change_circle),
                        label: const Text('Change Image'),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _pickScreenshot,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to upload screenshot',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
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
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'SUBMIT PAYMENT',
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
    );
  }
}
