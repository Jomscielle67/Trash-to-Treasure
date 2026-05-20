import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';  // Temporarily commented out
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:t2t_admin/models/admin_model.dart';

// T2T Theme colors
const Color kPrimaryGreen = Color(0xFF2E7D32);
const Color kAccentGreen = Color(0xFF4CAF50);
const Color kLightGreen = Color(0xFF66BB6A);
const Color kErrorRed = Color(0xFFE53E3E);

class EditProfileScreen extends StatefulWidget {
  final AdminModel admin;
  const EditProfileScreen({Key? key, required this.admin}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  File? _imageFile;
  String? _networkImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.admin.name);
    _networkImageUrl = widget.admin.imageUrl;
    print(
      'Edit Profile - Initial imageUrl: ${widget.admin.imageUrl}',
    ); // Debug print
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Helper method to get image provider
  ImageProvider? _getImageProvider() {
    try {
      if (_imageFile != null) {
        return FileImage(_imageFile!);
      } else if (_networkImageUrl != null && _networkImageUrl!.isNotEmpty) {
        if (_networkImageUrl!.startsWith('data:image')) {
          // Handle base64 images
          final base64String = _networkImageUrl!.split(',')[1];
          final bytes = base64Decode(base64String);
          return MemoryImage(bytes);
        } else {
          // Handle network URLs
          return NetworkImage(_networkImageUrl!);
        }
      }
    } catch (e) {
      print('Error loading image: $e');
    }
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        print('Image picked: ${pickedFile.path}');
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // Show feedback to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.image, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Image selected! Save to apply changes.'),
                ],
              ),
              backgroundColor: kAccentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to pick image: $e')),
              ],
            ),
            backgroundColor: kErrorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        String? imageUrl = _networkImageUrl;

        if (_imageFile != null) {
          // Convert image to base64 for storage in Firestore
          print('Converting image to base64...');
          final bytes = await _imageFile!.readAsBytes();

          // Compress the image if it's too large (limit to 1MB)
          if (bytes.length > 1024 * 1024) {
            print(
              'Image too large (${bytes.length} bytes), using placeholder instead',
            );
            imageUrl =
                'https://via.placeholder.com/150x150/4CAF50/FFFFFF?text=${Uri.encodeComponent(widget.admin.name.substring(0, 1).toUpperCase())}';
          } else {
            final base64String = base64Encode(bytes);
            imageUrl = 'data:image/jpeg;base64,$base64String';
            print(
              'Image converted to base64 (${base64String.length} characters)',
            );
          }

          /* Alternative: Firebase Storage upload (when enabled)
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('admin_profile_pictures')
              .child('${widget.admin.id}.jpg');
          await storageRef.putFile(_imageFile!);
          imageUrl = await storageRef.getDownloadURL();
          */
        } else if (imageUrl == null || imageUrl.isEmpty) {
          // Set a default profile image if none exists
          imageUrl =
              'https://via.placeholder.com/150x150/4CAF50/FFFFFF?text=${Uri.encodeComponent(widget.admin.name.substring(0, 1).toUpperCase())}';
        }

        final updatedAdmin = widget.admin.copyWith(
          name: _nameController.text.trim(),
          imageUrl: imageUrl,
        );

        print('Saving admin with imageUrl length: ${imageUrl.length}');

        await FirebaseFirestore.instance
            .collection('admins')
            .doc(widget.admin.id)
            .update(updatedAdmin.toMap());

        print('Admin profile updated successfully in Firestore');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Profile updated successfully!'),
                ],
              ),
              backgroundColor: kAccentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('Error saving profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Failed to update profile: $e')),
                ],
              ),
              backgroundColor: kErrorRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 10),
                        BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF2E7D32)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Picture Section
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                            BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFFC3D4C5),
                                          blurRadius: 12,
                                          offset: Offset(4, 4),
                                        ),
                                        BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 12,
                                          offset: Offset(-4, -4),
                                        ),
                                      ],
                                    ),
                                    child:
                                        _getImageProvider() != null
                                            ? CircleAvatar(
                                              radius: 50,
                                              backgroundColor: kLightGreen
                                                  .withOpacity(0.2),
                                              backgroundImage:
                                                  _getImageProvider(),
                                              onBackgroundImageError: (
                                                error,
                                                stackTrace,
                                              ) {
                                                print(
                                                  'Error loading edit profile image: $error',
                                                );
                                              },
                                            )
                                            : CircleAvatar(
                                              radius: 50,
                                              backgroundColor: kLightGreen
                                                  .withOpacity(0.2),
                                              child: const Icon(
                                                Icons.person,
                                                size: 50,
                                                color: kAccentGreen,
                                              ),
                                            ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2E7D32),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                              onPressed: _pickImage,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Tap camera icon to change photo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Form Fields Section
                          Card(
                            elevation: 4,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: kLightGreen.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Profile Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Name Field
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: InputDecoration(
                                        labelText: 'Full Name',
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: kAccentGreen,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: kErrorRed,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter your name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Email Field (Read-only)
                                    TextFormField(
                                      initialValue: widget.admin.email,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        labelText: 'Email (read-only)',
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(
                                          Icons.email_outlined,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Department Field (Read-only)
                                    TextFormField(
                                      initialValue: widget.admin.department,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        labelText: 'Department (read-only)',
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(
                                          Icons.business_outlined,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Save Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [kPrimaryGreen, kAccentGreen],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: kAccentGreen.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child:
                                  _isSaving
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
              ),
            ],
          ),
          ),
    );
  }
}
