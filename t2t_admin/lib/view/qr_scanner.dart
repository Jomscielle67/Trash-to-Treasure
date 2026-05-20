import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:t2t_admin/models/transaction_model.dart';
import 'package:t2t_admin/view/transaction_detail.dart';
import 'package:t2t_admin/widgets/neumorphic_card.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  BarcodeCapture? result;
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: const Text('QR Code Scanner', style: TextStyle(color: Color(0xFF1B5E20))),
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
        actions: [
          IconButton(
            color: const Color(0xFF2E7D32),
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            color: const Color(0xFF2E7D32),
            icon: const Icon(Icons.camera_rear),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                if (!_isProcessing && capture.barcodes.isNotEmpty) {
                  setState(() {
                    result = capture;
                    _isProcessing = true;
                  });
                  _processScannedData(capture.barcodes.first.rawValue);
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                if (result != null)
                  NeumorphicCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Scanned Data:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            result!.barcodes.first.rawValue ?? 'No data',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('Scan a QR code to verify transaction'),
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _processScannedData(String? data) async {
    if (data == null || data.isEmpty) {
      _showErrorDialog('Invalid QR Code', 'The scanned QR code is empty or invalid.');
      return;
    }

    try {
      final scanned = data.trim();
      TransactionModel? transaction;

      // Case 1: plain ticket code (e.g. T2T-ABC123) — produced by ticket_screen.dart
      if (RegExp(r'^T2T-[A-Z0-9]+$').hasMatch(scanned)) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('transactions')
            .where('ticketCode', isEqualTo: scanned)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          _showErrorDialog('Transaction Not Found', 'No transaction found with ticket code: $scanned');
          return;
        }

        final doc = querySnapshot.docs.first;
        transaction = TransactionModel.fromMap(doc.data(), doc.id);
      } else {
        // Case 2: structured QR data (pipe-separated key:value or JSON)
        final qrData = _parseQRData(scanned);

        if (qrData['type'] != 'transaction_verification') {
          _showErrorDialog('Invalid QR Code', 'This QR code is not a valid transaction verification code.');
          return;
        }

        final transactionId = qrData['transactionId'];
        final ticketCode = qrData['ticketCode'];

        if (transactionId == null || ticketCode == null) {
          _showErrorDialog('Invalid QR Code', 'Transaction ID or ticket code is missing.');
          return;
        }

        final doc = await FirebaseFirestore.instance
            .collection('transactions')
            .doc(transactionId)
            .get();

        if (!doc.exists) {
          _showErrorDialog('Transaction Not Found', 'The transaction does not exist in our database.');
          return;
        }

        transaction = TransactionModel.fromMap(doc.data()!, doc.id);

        if (transaction.ticketCode != ticketCode) {
          _showErrorDialog('Authentication Failed', 'The ticket code does not match our records. This transaction may be fraudulent.');
          return;
        }
      }

      _showAuthenticationResult(transaction, true);

    } catch (e) {
      _showErrorDialog('Error', 'Failed to verify the transaction: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, String?> _parseQRData(String data) {
    final Map<String, String?> result = {};
    
    try {
      // Try to parse as our custom format first (key:value|key:value)
      final parts = data.split('|');
      for (final part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          result[keyValue[0]] = keyValue[1];
        }
      }
      
      if (result.isNotEmpty) {
        return result;
      }
      
      // If custom format fails, try JSON
      final jsonData = json.decode(data) as Map<String, dynamic>;
      for (final entry in jsonData.entries) {
        result[entry.key] = entry.value?.toString();
      }
    } catch (e) {
      throw Exception('Unable to parse QR code data');
    }
    
    return result;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isProcessing = false;
                  result = null;
                });
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAuthenticationResult(TransactionModel transaction, bool isAuthentic) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isAuthentic ? Icons.check_circle : Icons.error,
                color: isAuthentic ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(isAuthentic ? 'Authentic Transaction' : 'Invalid Transaction'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAuthentic 
                    ? 'This transaction has been verified as authentic.'
                    : 'This transaction could not be verified and may be fraudulent.',
              ),
              const SizedBox(height: 16),
              Text('Transaction Details:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Student: ${transaction.studentName}'),
              Text('Ticket Code: ${transaction.ticketCode}'),
              Text('Points: ${transaction.points}'),
              Text('Status: ${transaction.status}'),
              if (transaction.rewardName != null)
                Text('Reward: ${transaction.rewardName}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isProcessing = false;
                  result = null;
                });
              },
              child: const Text('Close'),
            ),
            if (isAuthentic && transaction.type == 'redeem' && transaction.status == 'Pending')
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await FirebaseFirestore.instance
                        .collection('transactions')
                        .doc(transaction.id)
                        .update({'status': 'Completed'});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction approved!'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error approving: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  setState(() {
                    _isProcessing = false;
                    result = null;
                  });
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
              ),
            if (isAuthentic)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TransactionDetailScreen(transaction: transaction),
                    ),
                  );
                },
                child: const Text('View Details'),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}