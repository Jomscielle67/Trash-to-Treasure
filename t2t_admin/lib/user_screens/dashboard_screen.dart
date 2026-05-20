import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:t2t_admin/user_theme.dart';
import 'package:t2t_admin/user_screens/rewards_screen.dart';
import 'package:t2t_admin/user_screens/qr_screen.dart';
import 'package:t2t_admin/user_screens/profile_screen.dart';
import '../models/student_model.dart';
import '../models/transaction_model.dart';
import '../controllers/rewards_controller.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<_HomeDashboardState> _homeDashboardKey =
      GlobalKey<_HomeDashboardState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      _HomeDashboard(key: _homeDashboardKey),
      RewardsScreen(),
      QrScreen(),
      const ProfileScreen(),
    ];
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavBarTapped,
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey,
          backgroundColor: const Color(0xFFE8F5E9),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard),
              label: 'Rewards',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner),
              label: 'QR',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          elevation: 12,
        ),
    );
  }
}

// Home dashboard content
class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({super.key});

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  final RewardsController _rewardsController = RewardsController();
  StudentModel? _currentStudent;
  List<TransactionModel> _recentTransactions = [];
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  bool _isLoading = true;
  int _currentTipIndex = 0;

  @override
  void initState() {
    super.initState();
    loadUserData();
    _startTipRotation();
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _startTipRotation() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _ecoTips.length;
        });
        _startTipRotation();
      }
    });
  }

  void _nextTip() => setState(() => _currentTipIndex = (_currentTipIndex + 1) % _ecoTips.length);
  void _prevTip() => setState(() => _currentTipIndex = (_currentTipIndex - 1 + _ecoTips.length) % _ecoTips.length);

  // Each tip: {emoji, title, body, accent color}
  static const List<Map<String, dynamic>> _ecoTips = [
    {
      'emoji': '🔥',
      'title': 'Energy Saver',
      'body': 'Recycling just ONE plastic bottle saves enough energy to power a lightbulb for 3 hours!',
      'color': Color(0xFFFF6F00),
    },
    {
      'emoji': '🌊',
      'title': 'Ocean Guardian',
      'body': 'Every minute, a garbage truck\'s worth of plastic enters our oceans. YOU\'RE making a difference!',
      'color': Color(0xFF0277BD),
    },
    {
      'emoji': '⚡',
      'title': 'Power Up',
      'body': 'Recycling 1 ton of plastic saves 5,774 kWh of energy — enough to power a home for 6 months!',
      'color': Color(0xFFF9A825),
    },
    {
      'emoji': '🐢',
      'title': 'Wildlife Hero',
      'body': 'Sea turtles mistake plastic bags for jellyfish. Your recycling saves marine life!',
      'color': Color(0xFF00695C),
    },
    {
      'emoji': '🌍',
      'title': 'Tree Keeper',
      'body': 'If everyone recycled just 10% more, we\'d save 25 million trees annually. Keep it up!',
      'color': Color(0xFF2E7D32),
    },
    {
      'emoji': '💪',
      'title': 'Eco Hero',
      'body': 'You\'re a hero! Recycling reduces greenhouse gas emissions by up to 30%.',
      'color': Color(0xFF6A1B9A),
    },
    {
      'emoji': '🎯',
      'title': 'Future Fighter',
      'body': 'Plastic takes 450+ years to decompose. Every bottle you recycle prevents centuries of pollution!',
      'color': Color(0xFFC62828),
    },
    {
      'emoji': '🌟',
      'title': 'Inspiration',
      'body': 'Your actions inspire others! Studies show recycling habits are contagious in communities.',
      'color': Color(0xFF1565C0),
    },
    {
      'emoji': '🔄',
      'title': 'Circular Economy',
      'body': 'Recycled plastic can become clothes, furniture, and even new bottles. You\'re creating the future!',
      'color': Color(0xFF4527A0),
    },
    {
      'emoji': '🏆',
      'title': 'Champion',
      'body': 'Champions recycle! You\'re part of the solution, not the pollution.',
      'color': Color(0xFFE65100),
    },
  ];

  Future<void> loadUserData() async {
    try {
      final student = await _rewardsController.getCurrentStudent();
      if (student != null && mounted) {
        setState(() {
          _currentStudent = student;
          _isLoading = false;
        });

        _rewardsController.getUserTransactionsStream(student.id).listen((
          transactions,
        ) {
          if (mounted) {
            setState(() {
              _recentTransactions = transactions.take(3).toList();
            });
          }
        });

        _notifSubscription = FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: student.id)
            .limit(30)
            .snapshots()
            .listen(
              (snap) {
                if (mounted) {
                  // Sort client-side — avoids requiring a Firestore composite index
                  // on (userId, timestamp) which would cause a silent stream error.
                  final sorted =
                      snap.docs.map((d) => {'id': d.id, ...d.data()}).toList()
                        ..sort((a, b) {
                          final aTs = a['timestamp'];
                          final bTs = b['timestamp'];
                          if (aTs == null && bTs == null) return 0;
                          if (aTs == null) return 1;
                          if (bTs == null) return -1;
                          return (bTs as Timestamp).compareTo(aTs as Timestamp);
                        });
                  setState(() {
                    _notifications = sorted;
                  });
                }
              },
              onError: (Object e) {
                debugPrint('[Notifications] stream error: $e');
              },
            );
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getDateString() {
    final now = DateTime.now();
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
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  int _getUserLevel() {
    if (_currentStudent == null) return 1;
    return (_currentStudent!.points / 500).floor() + 1;
  }

  double _getLevelProgress() {
    if (_currentStudent == null) return 0.0;
    final pointsInCurrentLevel = _currentStudent!.points % 500;
    return pointsInCurrentLevel / 500.0;
  }

  String _getLevelTitle() {
    final level = _getUserLevel();
    if (level <= 2) return 'Eco Starter';
    if (level <= 4) return 'Green Helper';
    if (level <= 6) return 'Eco Warrior';
    if (level <= 9) return 'Planet Guardian';
    return 'Eco Legend';
  }

  String _getInitials() {
    final name = _currentStudent?.fullName ?? 'S';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'S';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F5E9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(),
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()} 👋',
                          style: textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4E7C52),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentStudent?.fullName ?? 'Student',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E20),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Date chip
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
                    child: Text(
                      _getDateString(),
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Notification bell
                  GestureDetector(
                    onTap: _showNotificationsPanel,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
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
                        if (_unreadCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _unreadCount > 9 ? '9+' : '$_unreadCount',
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
            ),
          ),

          // ── MAIN POINTS CARD ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  color: Color(0xFFE8F5E9),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                    BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_getLevelTitle()}  •  Lv ${_getUserLevel()}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_currentStudent?.points ?? 0}',
                            style: textTheme.displayLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 48,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'Total Points',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _getLevelProgress(),
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(_getLevelProgress() * 500).toInt()} / 500 pts to next level',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Bottles stat
                    Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.recycling,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentStudent?.bottles ?? 0}',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Bottles',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── QUICK ACTIONS ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.qr_code_scanner,
                      label: 'Scan Bottle',
                      color: AppColors.primary,
                      onTap: () {
                        // Navigate to QR tab (index 2)
                        final dashboard =
                            context
                                .findAncestorStateOfType<
                                  _UserDashboardScreenState
                                >();
                        dashboard?._onNavBarTapped(2);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.card_giftcard,
                      label: 'Rewards',
                      color: const Color(0xFFFF8F00),
                      onTap: () {
                        final dashboard =
                            context
                                .findAncestorStateOfType<
                                  _UserDashboardScreenState
                                >();
                        dashboard?._onNavBarTapped(1);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      color: const Color(0xFF5C6BC0),
                      onTap: () {
                        final dashboard =
                            context
                                .findAncestorStateOfType<
                                  _UserDashboardScreenState
                                >();
                        dashboard?._onNavBarTapped(3);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── RECENT ACTIVITY ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(6, 6), blurRadius: 15, spreadRadius: 1),
                    BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 15, spreadRadius: 1),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Recent Activity',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B5E20),
                                ),
                              ),
                            ],
                          ),
                          if (_recentTransactions.isNotEmpty)
                            Text(
                              'Last 3',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_recentTransactions.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 44,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No activity yet',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Start recycling to earn points!',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._recentTransactions.asMap().entries.map((entry) {
                          final i = entry.key;
                          final transaction = entry.value;
                          final isRedeem = transaction.type == 'redeem';
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color:
                                          isRedeem
                                              ? AppColors.error.withOpacity(0.1)
                                              : AppColors.primary.withOpacity(
                                                0.1,
                                              ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isRedeem
                                          ? Icons.shopping_bag_outlined
                                          : Icons.recycling,
                                      color:
                                          isRedeem
                                              ? AppColors.error
                                              : AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isRedeem
                                              ? 'Redeemed ${transaction.rewardName}'
                                              : 'Recycled bottle',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _formatTransactionDate(
                                            transaction.timestamp.toDate(),
                                          ),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isRedeem
                                              ? AppColors.error.withOpacity(0.1)
                                              : AppColors.primary.withOpacity(
                                                0.1,
                                              ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${isRedeem ? '-' : '+'}${transaction.points}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color:
                                            isRedeem
                                                ? AppColors.error
                                                : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (i < _recentTransactions.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── ECO TIP ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < -200) _nextTip();
                    if (details.primaryVelocity! > 200) _prevTip();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (_ecoTips[_currentTipIndex]['color'] as Color).withOpacity(0.85),
                        (_ecoTips[_currentTipIndex]['color'] as Color),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_ecoTips[_currentTipIndex]['color'] as Color).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Eco Tip',
                            style: textTheme.labelLarge?.copyWith(
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          // Prev button
                          GestureDetector(
                            onTap: _prevTip,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_left, color: Colors.white, size: 16),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Next button
                          GestureDetector(
                            onTap: _nextTip,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_right, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Emoji + content
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.15, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Row(
                          key: ValueKey<int>(_currentTipIndex),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Big emoji badge
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _ecoTips[_currentTipIndex]['emoji'] as String,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _ecoTips[_currentTipIndex]['title'] as String,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _ecoTips[_currentTipIndex]['body'] as String,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.88),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_ecoTips.length, (i) {
                          final active = i == _currentTipIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active ? Colors.white : Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  int get _unreadCount =>
      _notifications.where((n) => n['isRead'] != true).length;

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => n['isRead'] != true).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(n['id'] as String),
        {'isRead': true},
      );
    }
    await batch.commit();
  }

  Future<void> _markOneRead(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).update(
      {'isRead': true},
    );
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3),
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => DraggableScrollableSheet(
                  initialChildSize: 0.65,
                  maxChildSize: 0.92,
                  minChildSize: 0.4,
                  builder:
                      (_, scrollCtrl) => Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Notifications',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_notifications.isNotEmpty)
                                    TextButton(
                                      onPressed: () async {
                                        await _markAllRead();
                                        Navigator.of(ctx).pop();
                                      },
                                      child: const Text(
                                        'Clear all',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child:
                                  _notifications.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.notifications_off_outlined,
                                              size: 52,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No notifications yet',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'You\'ll see updates here',
                                              style: TextStyle(
                                                color: Colors.grey.shade400,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : ListView.separated(
                                        controller: scrollCtrl,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        itemCount: _notifications.length,
                                        separatorBuilder:
                                            (_, __) =>
                                                const SizedBox(height: 8),
                                        itemBuilder: (_, i) {
                                          final n = _notifications[i];
                                          return _NotificationItem(
                                            notification: n,
                                          );
                                        },
                                      ),
                            ),
                          ],
                        ),
                      ),
                ),
          ),
    ).then((_) => _markAllRead());
  }

  String _formatTransactionDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// ── Quick Action Card ──────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(color: Color(0xFFC3D4C5), offset: Offset(4, 4), blurRadius: 10),
            BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Item ─────────────────────────────────────────────────────────

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({required this.notification});
  final Map<String, dynamic> notification;

  IconData get _icon {
    final type = notification['type'] as String? ?? '';
    switch (type) {
      case 'deposit':
        return Icons.recycling;
      case 'redeem':
        return Icons.card_giftcard_rounded;
      case 'approved':
        return Icons.check_circle_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Color get _color {
    final type = notification['type'] as String? ?? '';
    switch (type) {
      case 'deposit':
        return const Color(0xFF16A34A);
      case 'redeem':
        return const Color(0xFFFF8F00);
      case 'approved':
        return AppColors.primary;
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    DateTime date;
    if (ts is Timestamp) {
      date = ts.toDate();
    } else {
      return '';
    }
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : _color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? const Color(0xFFE0E0E0) : _color.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'] as String? ?? 'Notification',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                if ((notification['body'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notification['body'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _timeAgo(notification['timestamp']),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}


