import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:t2t_admin/models/transaction_model.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  void _copyTicketCode(BuildContext context) {
    if (transaction.ticketCode != null) {
      Clipboard.setData(ClipboardData(text: transaction.ticketCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket code copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transaction Details',
                    style: t.headlineMedium?.copyWith(
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction Status Header
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFC3D4C5),
                            offset: Offset(6, 6),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-6, -6),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Transaction ID',
                                      style: t.titleMedium?.copyWith(
                                        color: const Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            transaction.status == 'Pending'
                                                ? Colors.orange.withOpacity(0.2)
                                                : Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        transaction.status,
                                        style: TextStyle(
                                          color:
                                              transaction.status == 'Pending'
                                                  ? Colors.orange
                                                  : Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  transaction.id,
                                  style: t.bodySmall?.copyWith(
                                    fontFamily: 'Courier',
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Transaction Details
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFC3D4C5),
                                offset: Offset(6, 6),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-6, -6),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transaction Information',
                                  style: t.titleLarge?.copyWith(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                _buildDetailRow(
                                  'Student Name',
                                  transaction.studentName,
                                  t,
                                ),
                                _buildDetailRow(
                                  'Transaction Type',
                                  transaction.type.toUpperCase(),
                                  t,
                                ),
                                _buildDetailRow(
                                  'Points',
                                  '${transaction.points} pts',
                                  t,
                                ),
                                _buildDetailRow(
                                  'Department',
                                  transaction.department,
                                  t,
                                ),
                                if (transaction.rewardName != null)
                                  _buildDetailRow(
                                    'Reward',
                                    transaction.rewardName!,
                                    t,
                                  ),
                                _buildDetailRow(
                                  'Date & Time',
                                  transaction.timestamp
                                      .toDate()
                                      .toString()
                                      .substring(0, 16),
                                  t,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Ticket Code Section (only for redemption transactions)
                        if (transaction.type == 'redeem' &&
                            transaction.ticketCode != null) ...[
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFC3D4C5),
                                  offset: Offset(6, 6),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-6, -6),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Ticket Code',
                                        style: t.titleLarge?.copyWith(
                                          color: const Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed:
                                            () => _copyTicketCode(context),
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Color(0xFF4CAF50),
                                        ),
                                        tooltip: 'Copy ticket code',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Ticket Code Display
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      transaction.ticketCode!,
                                      style: t.headlineSmall?.copyWith(
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // QR Code
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: QrImageView(
                                        data: _generateQRData(),
                                        version: QrVersions.auto,
                                        size: 200.0,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  Text(
                                    'This QR code contains the transaction verification data. '
                                    'Scan it to verify the authenticity of this redemption.',
                                    style: t.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Actions
                        if (transaction.type == 'redeem' &&
                            transaction.status == 'Pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('transactions')
                                      .doc(transaction.id)
                                      .update({'status': 'Completed'});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Transaction approved!'),
                                        backgroundColor: Color(0xFF4CAF50),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error approving: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Approve Transaction'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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

  Widget _buildDetailRow(String label, String value, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateQRData() {
    // Generate a JSON string with transaction verification data
    final verificationData = {
      'transactionId': transaction.id,
      'ticketCode': transaction.ticketCode,
      'studentName': transaction.studentName,
      'rewardName': transaction.rewardName,
      'points': transaction.points,
      'timestamp': transaction.timestamp.toDate().toIso8601String(),
      'status': transaction.status,
      'type': 'transaction_verification',
    };

    return verificationData.entries.map((e) => '${e.key}:${e.value}').join('|');
  }
}
