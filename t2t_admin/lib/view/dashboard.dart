import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:t2t_admin/view/profile.dart';
import 'package:t2t_admin/view/rewards.dart';
import 'package:t2t_admin/view/students.dart';
import 'package:t2t_admin/view/transactions.dart';
import 'package:t2t_admin/view/qr_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

// Small reusable KPI card used in the dashboard
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  const _KpiCard({Key? key, required this.title, required this.value, this.icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF4CAF50),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title, 
                    style: t.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value, 
              style: t.displayMedium?.copyWith(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _iconController;
  late final Animation<double> _iconRotationAnim;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _iconRotationAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.linear)
    );
    _iconController.repeat();
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  static final List<Widget> _pages = <Widget>[
    StudentsScreen(),
    TransactionsScreen(),
    RewardsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      extendBody: false,
      body: SafeArea(
        child: _selectedIndex == 0
            ? _DashboardHome(onNavigateToRewards: () => setState(() => _selectedIndex = 3))
            : _pages[_selectedIndex - 1],
      ),
      floatingActionButton: _selectedIndex == 0 ? Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFC3D4C5),
              offset: Offset(5, 5),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-5, -5),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QRScannerScreen()),
            );
          },
          backgroundColor: const Color(0xFF2E7D32),
          elevation: 0,
          tooltip: 'Scan QR Code',
          child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        ),
      ) : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFC3D4C5),
              offset: Offset(0, -4),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFE8F5E9),
          elevation: 0,
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: const Color(0xFF4E7C52),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Students'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Transactions'),
            BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  final VoidCallback? onNavigateToRewards;
  const _DashboardHome({Key? key, this.onNavigateToRewards}) : super(key: key);

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  List<Map<String, dynamic>> _redemptions = [];
  static final Set<String> _seenIds = {};
  StreamSubscription<QuerySnapshot>? _redemptionSub;

  // Machine task notifications
  List<Map<String, dynamic>> _machineTasks = [];
  static final Set<String> _seenTaskIds = {};
  StreamSubscription<QuerySnapshot>? _taskSub;

  int get _unreadTaskCount =>
      _machineTasks.where((t) => !_seenTaskIds.contains(t['id'] as String)).length;

  int get _totalUnreadCount => _unreadCount + _unreadTaskCount;

  @override
  void initState() {
    super.initState();
    _redemptionSub = FirebaseFirestore.instance
        .collection('transactions')
        .where('type', isEqualTo: 'redeem')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _redemptions =
              snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        });
      }
    });

    // Listen to machine task notifications assigned to this admin
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      _taskSub = FirebaseFirestore.instance
          .collection('machine_notifications')
          .where('assignedAdminId', isEqualTo: currentUid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() {
            _machineTasks =
                snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _redemptionSub?.cancel();
    _taskSub?.cancel();
    super.dispose();
  }

  int get _unreadCount =>
      _redemptions.where((r) => !_seenIds.contains(r['id'] as String)).length;

  void _markAllSeen() {
    setState(() {
      for (final r in _redemptions) {
        _seenIds.add(r['id'] as String);
      }
      for (final t in _machineTasks) {
        _seenTaskIds.add(t['id'] as String);
      }
    });
  }

  Future<void> _markRedemptionDone(Map<String, dynamic> redemption) async {
    final docId = redemption['id'] as String;
    final studentName = redemption['studentName'] as String? ?? 'Student';
    final rewardName = redemption['rewardName'] as String? ?? 'Reward';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark Redemption Completed'),
        content: Text(
          'Confirm that $studentName has received "$rewardName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(docId)
          .update({
        'status': 'Completed',
        'completedAt': Timestamp.now(),
        'completedBy': FirebaseAuth.instance.currentUser?.displayName ??
            FirebaseAuth.instance.currentUser?.email ??
            'Admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Redemption for $studentName marked as completed!'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showRedemptionsPanel(BuildContext context) {
    _markAllSeen();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DefaultTabController(
        length: 2,
        child: DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.92,
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                // Tab bar
                TabBar(
                  labelColor: const Color(0xFF4CAF50),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF4CAF50),
                  tabs: [
                    Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Redemptions'),
                        if (_unreadCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$_unreadCount',
                                style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      ]),
                    ),
                    Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Machine Tasks'),
                        if (_unreadTaskCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$_unreadTaskCount',
                                style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildRedemptionsList(scrollCtrl),
                      _buildMachineTasksList(scrollCtrl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRedemptionsList(ScrollController scrollCtrl) {
    if (_redemptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No redemptions yet',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _redemptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = _redemptions[i];
        final ts = r['timestamp'];
        final date = ts is Timestamp ? ts.toDate() : DateTime.now();
        final status = r['status'] as String? ?? 'Unknown';
        final isPending = status == 'Pending';
        return InkWell(
          onTap: isPending ? () => _markRedemptionDone(r) : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPending ? const Color(0xFFFF8F00).withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPending
                    ? const Color(0xFFFF8F00).withOpacity(0.3)
                    : Colors.grey.shade100,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8F00).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.card_giftcard_rounded,
                      color: Color(0xFFFF8F00), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['studentName'] as String? ?? 'Unknown Student',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 2),
                      Text('Redeemed: ${r['rewardName'] as String? ?? 'Reward'}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text('${r['points'] ?? 0} pts  •  ${_timeAgo(date)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      if (isPending) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Tap to mark as completed',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xFFFF8F00).withOpacity(0.12)
                            : const Color(0xFF16A34A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPending
                                  ? const Color(0xFFFF8F00)
                                  : const Color(0xFF16A34A))),
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 6),
                      const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFFFF8F00)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMachineTasksList(ScrollController scrollCtrl) {
    if (_machineTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No pending tasks — all clear!',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _machineTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final task = _machineTasks[i];
        final ts = task['createdAt'];
        final date = ts is Timestamp ? ts.toDate() : DateTime.now();
        final type = task['type'] as String? ?? '';
        final isUrgent = task['priority'] == 'urgent';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUrgent
                ? const Color(0xFFEF4444).withOpacity(0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUrgent
                  ? const Color(0xFFEF4444).withOpacity(0.35)
                  : Colors.grey.shade100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: type == 'empty_machine'
                          ? const Color(0xFFFF8F00).withOpacity(0.12)
                          : const Color(0xFF2196F3).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      type == 'empty_machine'
                          ? Icons.delete_sweep_rounded
                          : Icons.build_circle_rounded,
                      color: type == 'empty_machine'
                          ? const Color(0xFFFF8F00)
                          : const Color(0xFF2196F3),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['machineName'] as String? ?? 'Machine',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A)),
                        ),
                        Text(
                          task['machineLocation'] as String? ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('URGENT',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444))),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                type == 'empty_machine'
                    ? '🗑️ Empty Machine Request'
                    : '🔧 Maintenance Request',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(task['message'] as String? ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'From: ${task['createdBy'] ?? 'Super User'} • ${_timeAgo(date)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _markTaskDone(task),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Mark Done', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markTaskDone(Map<String, dynamic> task) async {
    final notifId = task['id'] as String;
    final machineName = task['machineName'] as String? ?? 'Machine';
    final taskType = task['type'] as String? ?? 'empty_machine';
    final machineDocId = task['machineDocId'] as String? ?? '';
    final machineId = task['machineId'] as String? ?? '';

    String? note;
    bool confirmed = false;
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(taskType == 'empty_machine'
            ? '🗑️ Mark Machine Emptied'
            : '🔧 Mark Maintenance Done'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Machine: $machineName',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Completion note (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              note = ctrl.text.trim();
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Confirm Done',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!confirmed) return;

    try {
      final adminName = FirebaseAuth.instance.currentUser?.displayName ??
          FirebaseAuth.instance.currentUser?.email ??
          'Admin';
      final now = Timestamp.now();

      // 1. Mark notification done
      await FirebaseFirestore.instance
          .collection('machine_notifications')
          .doc(notifId)
          .update({
        'status': 'done',
        'completedAt': now,
        'completedBy': adminName,
        'completionNote': note ?? '',
      });

      // 2. Update machine + add maintenance log
      if (machineDocId.isNotEmpty) {
        final machineRef =
            FirebaseFirestore.instance.collection('machines').doc(machineDocId);
        if (taskType == 'empty_machine') {
          await machineRef.update({
            'currentBottles': 0,
            'status': 'active',
            'updatedBy': adminName,
            'lastMaintenance': now,
          });
          await FirebaseFirestore.instance.collection('maintenance_logs').add({
            'machineId': machineId,
            'machineDocId': machineDocId,
            'maintenanceType': 'bottle_collection',
            'performedBy': adminName,
            'timestamp': now,
            'notes': 'Machine emptied. ${note ?? ''}',
            'status': 'completed',
          });
        } else {
          await machineRef.update({
            'lastMaintenance': now,
            'updatedBy': adminName,
            'status': 'active',
          });
          await FirebaseFirestore.instance.collection('maintenance_logs').add({
            'machineId': machineId,
            'machineDocId': machineDocId,
            'maintenanceType': 'routine',
            'performedBy': adminName,
            'timestamp': now,
            'notes': 'Maintenance completed. ${note ?? ''}',
            'status': 'completed',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Task done for $machineName!'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        // Close the bottom sheet so the task disappears from the list
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Future<List<Map<String, dynamic>>> _fetchWeeklyBottles() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    // Query transactions from the last 7 days (single-field filter — no composite index needed)
    // then filter type=='deposit' in Dart
    final snap = await FirebaseFirestore.instance
        .collection('transactions')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    // Build a map keyed by date string 'yyyy-MM-dd' -> bottle count
    final Map<String, int> bottlesByDay = {};
    for (var doc in snap.docs) {
      final data = doc.data();
      if ((data['type'] as String?) != 'deposit') continue;
      final ts = data['timestamp'];
      if (ts == null) continue;
      final date = (ts as Timestamp).toDate();
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      // Each deposit transaction = 1 bottle (points == bottles per transaction)
      final pts = (data['points'] as num?)?.toInt() ?? 1;
      bottlesByDay[key] = (bottlesByDay[key] ?? 0) + pts;
    }

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      // Use short day name from DateTime.weekday (1=Mon … 7=Sun)
      final label = dayNames[day.weekday - 1];
      final isToday = day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
      return {
        'day': label,
        'bottles': bottlesByDay[key] ?? 0,
        'isToday': isToday,
      };
    });
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    // Fetch students
    final studentsSnap = await FirebaseFirestore.instance.collection('students').get();
    final students = studentsSnap.docs;
    int totalPoints = 0;
    int totalBottles = 0;
    for (var doc in students) {
      final data = doc.data();
      totalPoints += (data['points'] ?? 0) as int;
      totalBottles += (data['bottles'] ?? 0) as int;
    }

    // Fetch pending redemptions
    final pendingSnap = await FirebaseFirestore.instance
        .collection('transactions')
        .where('status', isEqualTo: 'Pending')
        .get();
    int pendingRedemptions = pendingSnap.size;

    return {
      'totalPoints': totalPoints,
      'totalBottles': totalBottles,
      'studentCount': students.length,
      'pendingRedemptions': pendingRedemptions,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final text = t.textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        surfaceTintColor: const Color(0xFFE8F5E9),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                borderRadius: BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 10),
                  BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
                ],
              ),
              child: const Icon(
                Icons.recycling,
                color: Color(0xFF2E7D32),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Dashboard',
              style: text.headlineMedium?.copyWith(
                color: const Color(0xFF1B5E20),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => _showRedemptionsPanel(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(3, 3), blurRadius: 8),
                      BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                if (_totalUnreadCount > 0)
                  Positioned(
                    top: 4,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _totalUnreadCount > 9 ? '9+' : '$_totalUnreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
          future: _fetchStats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // show shimmer skeleton for initial load; make scrollable to avoid overflow on short screens
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
                child: Column(
                  children: [
                    Row(children: [Expanded(child: Shimmer(child: Container(height: 80, color: Colors.white,))), const SizedBox(width: 12), Expanded(child: Shimmer(child: Container(height: 80, color: Colors.white,)))]),
                    const SizedBox(height: 12),
                    Shimmer(child: Container(height: 200, color: Colors.white)),
                    const SizedBox(height: 12),
                    Row(children: [Expanded(child: Shimmer(child: Container(height: 80, color: Colors.white))), const SizedBox(width: 12), Expanded(child: Shimmer(child: Container(height: 80, color: Colors.white)))]),
                    const SizedBox(height: 12),
                    Shimmer(child: Container(height: 220, color: Colors.white)),
                  ],
                ),
              );
            }
            final stats = snapshot.data ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI row
                  Row(
                    children: [
                      Expanded(child: _KpiCard(title: 'Total Points', value: '${stats['totalPoints'] ?? 0}', icon: Icons.star)),
                      const SizedBox(width: 12),
                      Expanded(child: _KpiCard(title: 'Students', value: '${stats['studentCount'] ?? 0}', icon: Icons.group)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bottles per week chart
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
                                child: Icon(
                                  Icons.recycling,
                                  color: const Color(0xFF4CAF50),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Bottles Collected This Week', 
                                  style: text.headlineSmall?.copyWith(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: _fetchWeeklyBottles(),
                              builder: (context, chartSnap) {
                                if (chartSnap.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final data = chartSnap.data ?? [];
                                if (data.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox, size: 36, color: Colors.grey[400]),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'No bottle data for this week',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: () {
                                      final max = data.fold<int>(0, (m, e) => (e['bottles'] as int) > m ? (e['bottles'] as int) : m);
                                      return (max < 5 ? 5 : max + 2).toDouble();
                                    }(),
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          final bottles = rod.toY.toInt();
                                          return BarTooltipItem(
                                            '$bottles bottle${bottles == 1 ? '' : 's'}',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (value) => FlLine(
                                        color: Colors.grey.shade200,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          getTitlesWidget: (value, meta) {
                                            if (value == meta.max) return const SizedBox();
                                            return Text(
                                              value.toInt().toString(),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final idx = value.toInt();
                                            if (idx < 0 || idx >= data.length) return const SizedBox();
                                            final isToday = data[idx]['isToday'] as bool;
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                data[idx]['day'] as String,
                                                style: TextStyle(
                                                  color: isToday
                                                      ? const Color(0xFF2E7D32)
                                                      : Colors.grey.shade600,
                                                  fontWeight: isToday
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            );
                                          },
                                          reservedSize: 28,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: List.generate(
                                      data.length,
                                      (i) {
                                        final isToday = data[i]['isToday'] as bool;
                                        return BarChartGroupData(
                                          x: i,
                                          barRods: [
                                            BarChartRodData(
                                              toY: (data[i]['bottles'] as int).toDouble(),
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: isToday
                                                    ? [
                                                        const Color(0xFF1B5E20),
                                                        const Color(0xFF4CAF50),
                                                      ]
                                                    : [
                                                        const Color(0xFF4CAF50).withOpacity(0.6),
                                                        const Color(0xFF4CAF50),
                                                      ],
                                              ),
                                              width: 18,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Leaderboard for top 3 students
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
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
                                    child: Icon(
                                      Icons.emoji_events,
                                      color: const Color(0xFF4CAF50),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Top Students', 
                                    style: text.headlineSmall?.copyWith(
                                      color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance.collection('students').orderBy('points', descending: true).limit(3).get(),
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  final docs = snap.data?.docs ?? [];
                                  if (docs.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No students found.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    );
                                  }
                                  return Column(
                                    children: List.generate(
                                      docs.length,
                                      (i) {
                                        final data = docs[i].data() as Map<String, dynamic>;
                                        final name = data['fullName'] ?? 'Unknown';
                                        final points = data['points'] ?? 0;
                                        final bottles = data['bottles'] ?? 0;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: i == 0 ? Colors.amber : (i == 1 ? Colors.grey : Colors.brown[300]),
                                                child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(child: Text(
                                                name, 
                                                style: text.bodyLarge?.copyWith(
                                                  color: Colors.grey.shade800,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )),
                                              Text(
                                                '$points pts', 
                                                style: text.bodyMedium?.copyWith(
                                                  color: const Color(0xFF4CAF50),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '$bottles bottles', 
                                                style: text.bodySmall?.copyWith(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          title: 'Total Bottles',
                          value: '${stats['totalBottles'] ?? 0}',
                          icon: Icons.recycling,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          title: 'Pending Redemptions',
                          value: '${stats['pendingRedemptions'] ?? 0}',
                          icon: Icons.pending,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.card_giftcard,
                              color: const Color(0xFF4CAF50),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rewards',
                                  style: text.headlineSmall?.copyWith(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage reward items and stock',
                                  style: text.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                widget.onNavigateToRewards?.call();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Add Reward', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Recent Transactions
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
                      child: SizedBox(
                        height: 320,
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
                                  child: Icon(
                                    Icons.receipt_long,
                                    color: const Color(0xFF4CAF50),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Recent Transactions',
                                  style: text.headlineSmall?.copyWith(
                                    color: const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('transactions').orderBy('timestamp', descending: true).limit(5).snapshots(),
                              builder: (context, txSnapshot) {
                                if (txSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final docs = txSnapshot.data?.docs ?? [];
                                if (docs.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No recent transactions.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final data = docs[i].data() as Map<String, dynamic>;
                                    final student = data['studentName'] ?? 'Unknown';
                                    final type = data['type'] ?? '';
                                    final points = data['points'] ?? 0;
                                    final status = data['status'] ?? '';
                                    final ts = data['timestamp'];
                                    final date = ts is Timestamp ? ts.toDate() : DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now();
                                    return ListTile(
                                      leading: Icon(type == 'deposit' ? Icons.add : Icons.card_giftcard, color: type == 'deposit' ? Colors.green : Colors.orange),
                                      title: Text(
                                        student,
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${type[0].toUpperCase()}${type.substring(1)} • $points pts',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(status, style: TextStyle(color: status == 'Pending' ? Colors.red : Colors.green)),
                                          Text(
                                            '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}', 
                                            style: text.bodySmall?.copyWith(
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              )],
              ),
            );
          },
        ),
    );
  }
}