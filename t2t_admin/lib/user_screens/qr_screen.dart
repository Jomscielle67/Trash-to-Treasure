import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:t2t_admin/user_theme.dart';
import '../controllers/student_auth_controller.dart';
import '../models/student_model.dart';

// ── Helper ────────────────────────────────────────────────────────────────────
String _qrInitials(String fullName) {
  final parts = fullName.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';
}

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen>
    with SingleTickerProviderStateMixin {
  StudentModel? student;
  bool isLoading = true;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    try {
      final currentStudent = await StudentAuthController.getCurrentStudent();
      if (mounted) {
        setState(() {
          student = currentStudent;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showEnlargedQr(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFFE8F5E9),
          insetPadding: const EdgeInsets.all(24),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your QR Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (student != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: QrImageView(
                        data: student!.id,
                        version: QrVersions.auto,
                        size: 260,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    student?.fullName ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student?.studentID ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Tap anywhere to close',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        body: Center(child: CircularProgressIndicator(color: const Color(0xFF2E7D32))),
      );
    }

    if (student == null) {
      return const Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        body: Center(
          child: Text(
            'Failed to load student data.',
            style: TextStyle(color: const Color(0xFF1B5E20)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _qrInitials(student!.fullName),
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student!.fullName,
                          style: textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          student!.studentID,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF4E7C52),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Points chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(3, 3), blurRadius: 8),
                        BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFF2E7D32),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${student!.points} pts',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── QR CODE CARD ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                    BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  children: [
                    // QR code with pulse ring
                    GestureDetector(
                      onTap: () => _showEnlargedQr(context),
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(
                                    0.15 * _pulseAnim.value,
                                  ),
                                  blurRadius: 24 * _pulseAnim.value,
                                  spreadRadius: 4 * _pulseAnim.value,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.15),
                              width: 2,
                            ),
                          ),
                          child: QrImageView(
                            data: student!.id,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tap hint
                    GestureDetector(
                      onTap: () => _showEnlargedQr(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to enlarge',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Divider(color: Colors.grey.shade100),
                    const SizedBox(height: 16),

                    // Info row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Show this to the admin when depositing bottles or claiming rewards.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── STUDENT DETAILS CARD ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                    _DetailTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: student!.fullName,
                      isFirst: true,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _DetailTile(
                      icon: Icons.badge_outlined,
                      label: 'Student ID',
                      value: student!.studentID,
                      copyable: true,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _DetailTile(
                      icon: Icons.school_outlined,
                      label: 'Department',
                      value: student!.department,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _DetailTile(
                      icon: Icons.stars_rounded,
                      label: 'Points',
                      value: '${student!.points} points',
                      valueColor: AppColors.primary,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _DetailTile(
                      icon: Icons.recycling_rounded,
                      label: 'Bottles Recycled',
                      value: '${student!.bottles} bottles',
                      valueColor: const Color(0xFF0288D1),
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;
  final Color? valueColor;
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
          onTap:
              copyable
                  ? () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied!'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                  : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          color: valueColor ?? AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (copyable)
                  Icon(
                    Icons.copy_rounded,
                    size: 16,
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
