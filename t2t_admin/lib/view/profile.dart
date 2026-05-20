import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:t2t_admin/controllers/auth_controller.dart';
import 'package:t2t_admin/models/admin_model.dart';
import 'package:t2t_admin/view/edit_profile.dart';
import 'package:t2t_admin/view/login.dart';

// T2T Theme colors
const Color kPrimaryGreen = Color(0xFF2E7D32);
const Color kAccentGreen = Color(0xFF4CAF50);
const Color kLightGreen = Color(0xFF66BB6A);
const Color kErrorRed = Color(0xFFE53E3E);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController _authController = AuthController();
  AdminModel? _admin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    final user = _authController.currentUser;
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('admins')
                .doc(user.uid)
                .get();
        if (doc.exists) {
          if (mounted) {
            setState(() {
              final data = doc.data()!;
              data['id'] = doc.id; // Add document ID to the map
              _admin = AdminModel.fromMap(data);
              print('Admin ID: ${_admin?.id}'); // Debug print
              print('Admin imageUrl: ${_admin?.imageUrl}'); // Debug print
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        // Optionally: show a snackbar with the error
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to get image provider for profile pictures
  ImageProvider? _getProfileImageProvider() {
    try {
      if (_admin?.imageUrl != null && _admin!.imageUrl!.isNotEmpty) {
        if (_admin!.imageUrl!.startsWith('data:image')) {
          // Handle base64 images
          final base64String = _admin!.imageUrl!.split(',')[1];
          final bytes = base64Decode(base64String);
          return MemoryImage(bytes);
        } else {
          // Handle network URLs
          return NetworkImage(_admin!.imageUrl!);
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
    return null;
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
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const Spacer(),
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
                      icon: const Icon(Icons.logout, color: Color(0xFF2E7D32)),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFFE8F5E9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Color(0xFF1B5E20),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: const Text(
                              'Are you sure you want to sign out?',
                              style: TextStyle(color: Color(0xFF4E7C52)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Color(0xFF4E7C52)),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        await _authController.signOut();
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            kAccentGreen,
                          ),
                        ),
                      )
                      : _admin == null
                      ? const Center(
                        child: Text(
                          'No profile data found.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      )
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Profile Card
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
                                          _getProfileImageProvider() !=
                                                  null
                                              ? CircleAvatar(
                                                radius: 60,
                                                backgroundColor:
                                                    kLightGreen
                                                        .withOpacity(0.2),
                                                backgroundImage:
                                                    _getProfileImageProvider(),
                                                onBackgroundImageError: (
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        print(
                                                          'Error loading profile image: $error',
                                                        );
                                                      },
                                                    )
                                                    : CircleAvatar(
                                                      radius: 60,
                                                      backgroundColor:
                                                          kLightGreen
                                                              .withOpacity(0.2),
                                                      child: const Icon(
                                                        Icons.person,
                                                        size: 60,
                                                        color: kAccentGreen,
                                                      ),
                                                    ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            _admin!.name,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _admin!.email,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF6B7280),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kAccentGreen.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: kAccentGreen.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              'Department: ${_admin!.department}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: kPrimaryGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),

                                // Edit Profile Card
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
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 8,
                                          ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: kAccentGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit_outlined,
                                          color: kAccentGreen,
                                          size: 24,
                                        ),
                                      ),
                                      title: const Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Update your profile information',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                      onTap: () async {
                                        if (_admin != null) {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      EditProfileScreen(
                                                        admin: _admin!,
                                                      ),
                                            ),
                                          );
                                          // Refresh the profile data when returning from edit
                                          print(
                                            'Returning from edit profile, refreshing data...',
                                          );
                                          _fetchAdminData();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // App Info Card
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
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 8,
                                          ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: kLightGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.info_outline,
                                          color: kPrimaryGreen,
                                          size: 24,
                                        ),
                                      ),
                                      title: const Text(
                                        'App Info',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'About Trash to Treasure Admin',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                      onTap: () {
                                        showAboutDialog(
                                          context: context,
                                          applicationName:
                                              'Trash to Treasure Admin',
                                          applicationVersion: '1.0.0',
                                          applicationLegalese:
                                              '© 2024 T2T - Transforming Waste into Value',
                                          children: [
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: kAccentGreen.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Developed by: Pamis',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: kPrimaryGreen,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'An eco-friendly solution for waste management and rewards system.',
                                                    style: TextStyle(
                                                      color: Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
    );
  }
}