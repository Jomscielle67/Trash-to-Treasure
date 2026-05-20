import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';

class StudentDetailsScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailsScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _loadTransactions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load recent transactions for this student by their Firebase document ID
      final QuerySnapshot transactionSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: widget.student.id)
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          _transactions = transactionSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Transactions feature coming soon';
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String fieldName) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$fieldName copied to clipboard'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Invalid date';
      }
      
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
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
                    'Student Details',
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
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Section
                          Container(
                            width: double.infinity,
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
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: const Color(0xFF2E7D32),
                                    child: Text(
                                      widget.student.fullName.isNotEmpty ? widget.student.fullName.split(' ').map((name) => name[0].toUpperCase()).take(2).join('') : 'U',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.student.fullName,
                                    style: t.headlineSmall?.copyWith(
                                      color: const Color(0xFF1B5E20),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.student.studentID,
                                    style: t.bodyLarge?.copyWith(
                                      color: const Color(0xFF4E7C52),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Personal Information Cards
                          Row(
                            children: [
                              Expanded(
                                child: _InfoCard(
                                  icon: Icons.email,
                                  title: 'Email',
                                  value: widget.student.email,
                                  color: Colors.orange,
                                  onTap: () => _copyToClipboard(widget.student.email, 'Email'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoCard(
                                  icon: Icons.business,
                                  title: 'Department',
                                  value: widget.student.department,
                                  color: Colors.purple,
                                  onTap: () => _copyToClipboard(widget.student.department, 'Department'),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Points and Bottles Cards
                          Row(
                            children: [
                              Expanded(
                                child: _InfoCard(
                                  icon: Icons.star,
                                  title: 'Points',
                                  value: '${widget.student.points}',
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoCard(
                                  icon: Icons.recycling,
                                  title: 'Bottles',
                                  value: '${widget.student.bottles}',
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Transaction History Section
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
                                          Icons.history,
                                          color: Color(0xFF4CAF50),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Recent Transactions',
                                        style: t.headlineSmall?.copyWith(
                                          color: const Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_isLoading)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_errorMessage != null)
                                    Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: Colors.red.shade400,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red.shade600,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton(
                                            onPressed: _loadTransactions,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4CAF50),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_transactions.isEmpty && !_isLoading)
                                    Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No transactions yet',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Transaction history will appear here',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_transactions.isNotEmpty)
                                    Column(
                                      children: _transactions.map((transaction) {
                                        // Safely extract transaction data with fallbacks
                                        final type = (transaction['type'] as String?) ?? 'unknown';
                                        final points = (transaction['points'] as num?)?.toInt() ?? 0;
                                        final status = (transaction['status'] as String?) ?? 'Unknown';
                                        final timestamp = transaction['timestamp'];
                                        
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: type == 'deposit' 
                                                      ? Colors.green.withOpacity(0.1)
                                                      : Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  type == 'deposit' ? Icons.add : Icons.card_giftcard,
                                                  color: type == 'deposit' ? Colors.green : Colors.orange,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1)}' : 'Transaction',
                                                      style: TextStyle(
                                                        color: Colors.grey.shade800,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _formatDate(timestamp),
                                                      style: TextStyle(
                                                        color: Colors.grey.shade500,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '$points pts',
                                                    style: const TextStyle(
                                                      color: Color(0xFF4CAF50),
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: status == 'Pending' 
                                                          ? Colors.orange.withOpacity(0.1)
                                                          : Colors.green.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      status,
                                                      style: TextStyle(
                                                        color: status == 'Pending' ? Colors.orange : Colors.green,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          borderRadius: BorderRadius.all(Radius.circular(16)),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: t.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.copy,
                      color: color.withOpacity(0.6),
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: t.titleLarge?.copyWith(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}