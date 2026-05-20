import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/transaction_model.dart';
import '../models/reward_model.dart';
import 'package:t2t_admin/user_theme.dart';
import '../services/pdf_service.dart';

class TicketScreen extends StatelessWidget {
  final TransactionModel transaction;
  final RewardModel? reward;

  const TicketScreen({super.key, required this.transaction, this.reward});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isPending = transaction.status.toLowerCase() == 'pending';
    final statusColor = isPending ? Colors.orange[700]! : Colors.green[700]!;
    final statusBg =
        isPending
            ? Colors.orange.withOpacity(0.12)
            : Colors.green.withOpacity(0.12);

    return Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        body: CustomScrollView(
          slivers: [
            // ── HEADER ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 10),
                            BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF2E7D32),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reward Ticket',
                            style: textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF1B5E20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            transaction.rewardName ?? 'Redemption',
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF4E7C52),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _downloadTicketPDF(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(3, 3), blurRadius: 8),
                            BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'PDF',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── REWARD CARD (image + name + seal) ───────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                    BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                  ],
                ),
                child: Column(
                  children: [
                    // Reward image
                    ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child:
                              reward?.imageUrl != null &&
                                      reward!.imageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: reward!.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (context, url) => Container(
                                          color: AppColors.primary.withOpacity(
                                            0.08,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) =>
                                            _rewardPlaceholder(),
                                  )
                                  : _rewardPlaceholder(),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              transaction.rewardName ?? 'Unknown Reward',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            // Status + points row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPending
                                            ? Icons.schedule_rounded
                                            : Icons.check_circle_rounded,
                                        size: 13,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _getStatusText(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        size: 13,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '-${transaction.points} pts',
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Authentic seal inside the card
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8F00),
                                    Color(0xFFFFCA28),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'AUTHENTIC TICKET',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
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
            ),

            // ── TICKET DETAILS ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section heading
                    Row(
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
                          'Ticket Details',
                          style: textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
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
                            icon: Icons.confirmation_number_outlined,
                            label: 'Ticket Code',
                            value: transaction.ticketCode ?? 'N/A',
                            isFirst: true,
                            monospace: true,
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _DetailTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Student',
                            value: transaction.studentName,
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _DetailTile(
                            icon: Icons.school_outlined,
                            label: 'Department',
                            value: transaction.department,
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _DetailTile(
                            icon: Icons.calendar_today_outlined,
                            label: 'Date',
                            value: _formatDate(transaction.timestamp.toDate()),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── QR CODE ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                          'Verification QR',
                          style: textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                          BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: QrImageView(
                              data: transaction.ticketCode ?? '',
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            transaction.ticketCode ?? '',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 2.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Show this to the admin for redemption',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── DOWNLOAD BUTTON ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadTicketPDF(context),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Download Ticket PDF',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F5E9),
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _rewardPlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.08),
      child: const Center(
        child: Icon(
          Icons.card_giftcard_rounded,
          size: 80,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (transaction.status.toLowerCase()) {
      case 'pending':
        return 'Pending Approval';
      case 'completed':
        return 'Approved';
      default:
        return transaction.status;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadTicketPDF(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(width: 20),
                  Text('Generating PDF...'),
                ],
              ),
            ),
      );

      await PDFService.generateAndSaveTicketPDF(transaction, reward);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ticket PDF downloaded successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// ── Supporting Widget ─────────────────────────────────────────────────────────

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(20) : Radius.zero,
      bottom: isLast ? const Radius.circular(20) : Radius.zero,
    );
    return ClipRRect(
      borderRadius: radius,
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
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: monospace ? 'monospace' : null,
                      letterSpacing: monospace ? 1.5 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
