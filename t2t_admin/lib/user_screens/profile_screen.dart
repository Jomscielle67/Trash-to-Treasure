import 'package:flutter/material.dart';
import 'package:t2t_admin/user_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:t2t_admin/controllers/student_auth_controller.dart';
import 'package:t2t_admin/controllers/rewards_controller.dart';
import 'package:t2t_admin/models/student_model.dart';
import 'package:t2t_admin/models/transaction_model.dart';
import 'package:t2t_admin/user_screens/ticket_screen.dart';
import 'package:t2t_admin/view/login.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────
String _getProfileInitials(String fullName) {
  final parts = fullName.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';
}

int _getProfileLevel(int points) => (points / 500).floor() + 1;

String _getProfileLevelTitle(int points) {
  final level = _getProfileLevel(points);
  if (level <= 2) return 'Eco Starter';
  if (level <= 4) return 'Green Helper';
  if (level <= 6) return 'Eco Warrior';
  if (level <= 9) return 'Planet Guardian';
  return 'Eco Legend';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final RewardsController _rewardsController = RewardsController();
  StudentModel? _currentStudent;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadCurrentStudent();
    _loadNotificationsPreference();
  }

  Future<void> _loadCurrentStudent() async {
    try {
      final student = await _rewardsController.getCurrentStudent();
      setState(() {
        _currentStudent = student;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await StudentAuthController.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showTicketScreen(TransactionModel transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => TicketScreen(transaction: transaction, reward: null),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final isRedemption = transaction.type == 'redeem';
    final iconColor = isRedemption ? AppColors.error : AppColors.primary;
    final iconBg = iconColor.withOpacity(0.12);
    final pointsLabel = '${isRedemption ? '-' : '+'}${transaction.points} pts';

    Color badgeColor;
    Color badgeText;
    if (transaction.status == 'Pending') {
      badgeColor = Colors.orange.withOpacity(0.15);
      badgeText = Colors.orange[800]!;
    } else {
      badgeColor = Colors.green.withOpacity(0.15);
      badgeText = Colors.green[800]!;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              isRedemption && transaction.ticketCode != null
                  ? () => _showTicketScreen(transaction)
                  : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon square
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isRedemption ? Icons.redeem : Icons.recycling,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Title + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRedemption
                            ? (transaction.rewardName ?? 'Reward Redemption')
                            : 'Bottle Deposit',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(transaction.timestamp.toDate()),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Points badge + optional status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pointsLabel,
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (transaction.ticketCode != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          transaction.status,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isRedemption && transaction.ticketCode != null) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _currentStudent?.fullName ?? '',
    );
    File? selectedImage;
    String? imageUrl = _currentStudent?.profileImageUrl;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Profile',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF1A1A1A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 75,
                          );

                          if (image != null) {
                            setDialogState(() {
                              selectedImage = File(image.path);
                            });
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade100,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                                image:
                                    selectedImage != null
                                        ? DecorationImage(
                                          image: FileImage(selectedImage!),
                                          fit: BoxFit.cover,
                                        )
                                        : imageUrl != null
                                        ? DecorationImage(
                                          image: NetworkImage(imageUrl),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child:
                                  selectedImage == null && imageUrl == null
                                      ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppColors.primary,
                                      )
                                      : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to change photo',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        style: const TextStyle(color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _saveProfile(
                              dialogContext,
                              nameController.text,
                              selectedImage,
                            );
                          },
                          icon: const Icon(Icons.save),
                          label: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveProfile(
    BuildContext dialogContext,
    String newName,
    File? imageFile,
  ) async {
    if (_currentStudent == null) return;

    if (newName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
    );

    try {
      String? newImageUrl;

      if (imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${_currentStudent!.id}.jpg');

        await storageRef.putFile(imageFile);
        newImageUrl = await storageRef.getDownloadURL();
      }

      final updates = <String, dynamic>{'fullName': newName.trim()};

      if (newImageUrl != null) {
        updates['profileImageUrl'] = newImageUrl;
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(_currentStudent!.id)
          .update(updates);

      await StudentAuthController.currentUser?.updateDisplayName(
        newName.trim(),
      );

      await _loadCurrentStudent();

      Navigator.of(dialogContext).pop();
      Navigator.of(dialogContext).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(dialogContext).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadNotificationsPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _notificationsEnabled = doc.data()?['notificationsEnabled'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .update({'notificationsEnabled': value});
    } catch (_) {
      if (mounted) setState(() => _notificationsEnabled = !value);
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Change Password'),
          ],
        ),
        content: Text(
          'A password reset link will be sent to:\n${_currentStudent?.email ?? 'your email'}.',
          style: const TextStyle(color: Color(0xFF374151), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: _currentStudent!.email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reset link sent! Check your inbox.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.recycling, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trash to Treasure',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'A bottle recycling rewards platform that helps students earn points by recycling and redeeming them for exciting rewards.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                height: 1.5,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '© 2026 T2T Team',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpFAQBottomSheet() {
    const faqs = [
      {
        'q': 'How do I earn points?',
        'a': 'Bring plastic bottles to any T2T machine on campus. Each bottle earns you points automatically.',
      },
      {
        'q': 'How do I redeem a reward?',
        'a': 'Go to the Rewards tab, choose a reward, and tap "Redeem Now". A QR ticket will be generated.',
      },
      {
        'q': 'How do I claim my reward?',
        'a': 'Show your QR ticket to the assigned teacher or staff member for verification and approval.',
      },
      {
        'q': 'Why is my redemption still Pending?',
        'a': 'Your ticket is waiting for a staff member to scan and approve it. This usually takes a short time.',
      },
      {
        'q': 'Can I see my transaction history?',
        'a': 'Yes! Scroll up in your profile to see all your past deposits and redemptions.',
      },
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFE8F5E9),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Help & FAQ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  itemCount: faqs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _FAQItem(
                    question: faqs[i]['q']!,
                    answer: faqs[i]['a']!,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account and all your data. This cannot be undone.',
              style: TextStyle(color: Color(0xFF374151), height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your password to confirm:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final password = passwordCtrl.text;
    if (password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password is required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .delete();
      await user.delete();
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final message =
          (e is FirebaseAuthException && e.code == 'wrong-password')
              ? 'Incorrect password. Please try again.'
              : 'Failed to delete account.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildPaginationControls(int totalItems) {
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor:
                  _currentPage > 0
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.grey[200],
              foregroundColor:
                  _currentPage > 0 ? AppColors.primary : Colors.grey,
            ),
          ),
          const SizedBox(width: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentPage + 1} / $totalPages',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 16),
          IconButton(
            onPressed:
                _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              backgroundColor:
                  _currentPage < totalPages - 1
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.grey[200],
              foregroundColor:
                  _currentPage < totalPages - 1
                      ? AppColors.primary
                      : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        body: Center(child: CircularProgressIndicator(color: const Color(0xFF2E7D32))),
      );
    }

    if (_currentStudent == null) {
      return const Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        body: Center(
          child: Text(
            'Failed to load user data. Please try again.',
            style: TextStyle(color: const Color(0xFF1B5E20)),
          ),
        ),
      );
    }

    final student = _currentStudent!;
    final level = _getProfileLevel(student.points);
    final levelTitle = _getProfileLevelTitle(student.points);
    final levelProgress = (student.points % 500) / 500.0;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: CustomScrollView(
        slivers: [
          // ── PROFILE HERO CARD ──────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                    BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child:
                                    student.profileImageUrl != null
                                        ? Image.network(
                                          student.profileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) => _initialsAvatar(
                                                student.fullName,
                                              ),
                                        )
                                        : _initialsAvatar(student.fullName),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _showEditProfileDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.fullName,
                                style: textTheme.titleLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                student.email,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  student.department,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 16),

                    // Stats row
                    Row(
                      children: [
                        _ProfileStatChip(
                          icon: Icons.stars_rounded,
                          value: '${student.points}',
                          label: 'Points',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        _ProfileStatChip(
                          icon: Icons.recycling,
                          value: '${student.bottles}',
                          label: 'Bottles',
                          color: const Color(0xFF0288D1),
                        ),
                        const SizedBox(width: 10),
                        _ProfileStatChip(
                          icon: Icons.emoji_events_rounded,
                          value: 'Lv $level',
                          label: levelTitle,
                          color: const Color(0xFFE67E22),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Level progress
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Level Progress',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(levelProgress * 500).toInt()} / 500 pts',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: levelProgress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── TRANSACTION HISTORY ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Transaction History',
                    style: textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<List<TransactionModel>>(
                stream: _rewardsController.getUserTransactionsStream(
                  student.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: const Color(0xFF2E7D32)),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading transactions',
                        style: TextStyle(color: const Color(0xFF4E7C52)),
                      ),
                    );
                  }

                  final allTransactions = snapshot.data ?? [];

                  if (allTransactions.isEmpty) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 10),
                          BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 52,
                            color: const Color(0xFF2E7D32),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet',
                            style: textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF4E7C52),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Start recycling bottles to earn points!',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final startIndex = _currentPage * _itemsPerPage;
                  final endIndex = (startIndex + _itemsPerPage).clamp(
                    0,
                    allTransactions.length,
                  );
                  final paginatedTransactions = allTransactions.sublist(
                    startIndex,
                    endIndex,
                  );

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${startIndex + 1}–$endIndex of ${allTransactions.length}',
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF4E7C52),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _currentPage = 0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    size: 14,
                                    color: const Color(0xFF4E7C52),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Refresh',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF4E7C52),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...paginatedTransactions.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildTransactionCard(t),
                        ),
                      ),
                      _buildPaginationControls(allTransactions.length),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── SETTINGS CARD ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                    BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                  ],
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.edit_outlined,
                      iconColor: AppColors.primary,
                      label: 'Edit Profile',
                      onTap: _showEditProfileDialog,
                      isFirst: true,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _SettingsTile(
                      icon: Icons.lock_reset,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Change Password',
                      onTap: _showChangePasswordDialog,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Notifications',
                      onTap: () => _toggleNotifications(!_notificationsEnabled),
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeColor: AppColors.primary,
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      iconColor: const Color(0xFF6366F1),
                      label: 'About',
                      onTap: _showAboutDialog,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Help & FAQ',
                      onTap: _showHelpFAQBottomSheet,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _SettingsTile(
                      icon: Icons.delete_forever_outlined,
                      iconColor: AppColors.error,
                      label: 'Delete Account',
                      labelColor: AppColors.error,
                      onTap: _handleDeleteAccount,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.error,
                      label: 'Logout',
                      labelColor: AppColors.error,
                      onTap: _handleLogout,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String fullName) {
    return Container(
      color: AppColors.primary.withOpacity(0.15),
      child: Center(
        child: Text(
          _getProfileInitials(fullName),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ),
    );
  }
}

// ── Supporting Widgets ───────────────────────────────────────────────────────

class _ProfileStatChip extends StatelessWidget {
  const _ProfileStatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.75),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailing,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Widget? trailing;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(20) : Radius.zero,
      bottom: isLast ? const Radius.circular(20) : Radius.zero,
    );
    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: labelColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  const _FAQItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? AppColors.primary.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'Q',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.answer,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
