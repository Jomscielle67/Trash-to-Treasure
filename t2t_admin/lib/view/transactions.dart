import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:t2t_admin/models/transaction_model.dart';
import 'package:t2t_admin/view/transaction_detail.dart';
import 'package:t2t_admin/view/qr_scanner.dart';

final transactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('transactions')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList());
});

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final transactionsAsync = ref.watch(transactionsProvider);

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
                  Text(
                    'Transactions',
                    style: t.headlineMedium?.copyWith(
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(3, 3), blurRadius: 8),
                        BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2E7D32)),
                      tooltip: 'Scan QR Code',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRScannerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(3, 3), blurRadius: 8),
                        BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.filter_list, color: Color(0xFF2E7D32)),
                      onPressed: () => _selectDate(context),
                    ),
                  ),
                  if (_selectedDate != null) ...[                    
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(3, 3), blurRadius: 8),
                          BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF2E7D32)),
                        onPressed: () {
                          setState(() {
                            _selectedDate = null;
                          });
                        },
                      ),
                    ),
                  ]
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
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
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Color(0xFF4CAF50),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Recent Activity',
                                      style: t.headlineMedium?.copyWith(
                                        color: const Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedDate == null
                                      ? 'View and verify student transactions'
                                      : 'Filtered by: ${_selectedDate.toString().substring(0, 10)}',
                                  style: t.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
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
                            child: transactionsAsync.when(
                              data: (transactions) {
                                final filteredTransactions = _selectedDate == null
                                    ? transactions
                                    : transactions.where((tx) {
                                        final txDate = tx.timestamp.toDate();
                                        return txDate.year == _selectedDate!.year &&
                                            txDate.month == _selectedDate!.month &&
                                            txDate.day == _selectedDate!.day;
                                      }).toList();

                                if (filteredTransactions.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No transactions found',
                                            style: t.bodyLarge?.copyWith(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFF4CAF50).withOpacity(0.1),
                                      ),
                                      columns: [
                                        DataColumn(
                                          label: Text(
                                            'Student',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Type',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Points',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Status',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Date',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Actions',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: filteredTransactions.map((tx) {
                                        return DataRow(
                                          onSelectChanged: (selected) {
                                            if (selected == true) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => TransactionDetailScreen(transaction: tx),
                                                ),
                                              );
                                            }
                                          },
                                          cells: [
                                            DataCell(
                                              Text(
                                                tx.studentName,
                                                style: TextStyle(
                                                  color: Colors.grey.shade800,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                tx.type,
                                                style: TextStyle(
                                                  color: Colors.grey.shade800,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                tx.points.toString(),
                                                style: TextStyle(
                                                  color: const Color(0xFF4CAF50),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: tx.status == 'Pending' ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  tx.status,
                                                  style: TextStyle(
                                                    color: tx.status == 'Pending' ? Colors.orange : Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                tx.timestamp.toDate().toString().substring(0, 10),
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.visibility, size: 20, color: Color(0xFF4CAF50)),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => TransactionDetailScreen(transaction: tx),
                                                        ),
                                                      );
                                                    },
                                                    tooltip: 'View Details',
                                                  ),
                                                  if (tx.type == 'redeem' && tx.status == 'Pending')
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        FirebaseFirestore.instance
                                                            .collection('transactions')
                                                            .doc(tx.id)
                                                            .update({'status': 'Completed'});
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF4CAF50),
                                                        foregroundColor: Colors.white,
                                                        minimumSize: const Size(60, 30),
                                                      ),
                                                      child: const Text('Approve'),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
                              error: (err, stack) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading transactions',
                                      style: t.bodyLarge?.copyWith(
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
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
}

