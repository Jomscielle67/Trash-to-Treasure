import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:t2t_admin/user_theme.dart';
import '../controllers/rewards_controller.dart';
import '../models/reward_model.dart';
import '../models/student_model.dart';

enum _FilterType { all, canRedeem, outOfStock }

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  final RewardsController _rewardsController = RewardsController();
  final TextEditingController _searchController = TextEditingController();
  StudentModel? _currentStudent;
  bool _isLoading = true;
  String _searchQuery = '';
  _FilterType _filter = _FilterType.all;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _loadCurrentStudent();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentStudent() async {
    try {
      final student = await _rewardsController.getCurrentStudent();
      setState(() {
        _currentStudent = student;
        _isLoading = false;
      });
      _headerAnimController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading user data: $e')));
      }
    }
  }

  Future<void> _redeemReward(RewardModel reward) async {
    if (_currentStudent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User data not available')));
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _RedeemBottomSheet(
        reward: reward,
        student: _currentStudent!,
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _rewardsController.redeemReward(reward);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (result == 'Reward redeemed successfully!') {
        await _loadCurrentStudent();
        _showResultSnackbar(result, success: true);
      } else {
        _showResultSnackbar(result, success: false);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showResultSnackbar('Error: $e', success: false);
    }
  }

  void _showResultSnackbar(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? AppColors.primary : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildHeroCard() {
    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Balance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_currentStudent!.points}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'pts',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_drink_outlined,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_currentStudent!.bottles} bottles recycled',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFFD600),
                size: 42,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const labels = ['All', 'Can Redeem', 'Out of Stock'];
    const icons = [
      Icons.grid_view_rounded,
      Icons.check_circle_outline_rounded,
      Icons.remove_shopping_cart_outlined,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _FilterType.values.map((f) {
            final isSelected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  icons[f.index],
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
                label: Text(labels[f.index]),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _filter = f;
                    _currentPage = 0;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.neuBase,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.neuDark,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                showCheckmark: false,
                elevation: isSelected ? 3 : 0,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRewardCard(RewardModel reward) {
    final canRedeem =
        _currentStudent != null &&
        _currentStudent!.points >= reward.cost &&
        reward.stock > 0;
    final hasImage = reward.imageUrl != null && reward.imageUrl!.isNotEmpty;
    final pointsNeeded =
        _currentStudent != null
            ? (reward.cost - _currentStudent!.points).clamp(0, reward.cost)
            : reward.cost;
    final progress =
        _currentStudent != null
            ? (_currentStudent!.points / reward.cost).clamp(0.0, 1.0)
            : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.neuBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              canRedeem
                  ? AppColors.primary.withOpacity(0.45)
                  : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                canRedeem
                    ? AppColors.primary.withOpacity(0.15)
                    : const Color(0xFFC3D4C5),
            offset: const Offset(6, 6),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image with overlay badges ──────────────────────
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: hasImage
                    ? _buildRewardImage(reward.imageUrl!, height: 150)
                    : _placeholderImage(),
              ),
              // Stock badge (top-right)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        reward.stock > 0
                            ? Colors.green.shade700
                            : Colors.red.shade600,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reward.stock > 0
                            ? Icons.inventory_2_outlined
                            : Icons.remove_shopping_cart_outlined,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reward.stock > 0
                            ? '${reward.stock} left'
                            : 'Out of Stock',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // "Redeemable" badge (top-left)
              if (canRedeem)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 11,
                          color: Color(0xFF1B5E20),
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Redeemable',
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Card body ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  reward.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Cost chip + "need more" hint
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reward.cost} pts',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pointsNeeded > 0 && reward.stock > 0) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Need $pointsNeeded more',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                // Progress bar toward cost
                if (reward.stock > 0 && _currentStudent != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.toDouble(),
                      minHeight: 6,
                      backgroundColor: AppColors.neuDark.withOpacity(0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        canRedeem ? AppColors.primary : Colors.orange.shade400,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Redeem button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canRedeem ? () => _redeemReward(reward) : null,
                    icon: Icon(
                      canRedeem
                          ? Icons.redeem_rounded
                          : reward.stock <= 0
                          ? Icons.remove_shopping_cart_outlined
                          : Icons.lock_outline_rounded,
                      size: 17,
                    ),
                    label: Text(
                      canRedeem
                          ? 'Redeem Now'
                          : reward.stock <= 0
                          ? 'Out of Stock'
                          : 'Not Enough Points',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canRedeem ? AppColors.primary : Colors.grey.shade200,
                      foregroundColor:
                          canRedeem ? Colors.white : Colors.grey.shade500,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: canRedeem ? 3 : 0,
                      shadowColor:
                          canRedeem
                              ? AppColors.primary.withOpacity(0.4)
                              : Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRewardImage(String imageUrl, {double height = 150}) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str =
            imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderImage(height: height),
        );
      } catch (_) {
        return _placeholderImage(height: height);
      }
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholderImage(height: height),
      errorWidget: (_, __, ___) => _placeholderImage(height: height),
    );
  }

  Widget _placeholderImage({double height = 150}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.06),
            AppColors.primary.withOpacity(0.13),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.card_giftcard_rounded,
        size: 60,
        color: AppColors.primary.withOpacity(0.35),
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PagButton(
            icon: Icons.chevron_left,
            enabled: _currentPage > 0,
            onTap: () => setState(() => _currentPage--),
          ),
          const SizedBox(width: 12),
          ...List.generate(totalPages, (i) {
            final isActive = i == _currentPage;
            return GestureDetector(
              onTap: () => setState(() => _currentPage = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.neuDark,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
          const SizedBox(width: 12),
          _PagButton(
            icon: Icons.chevron_right,
            enabled: _currentPage < totalPages - 1,
            onTap: () => setState(() => _currentPage++),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_currentStudent == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load user data',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadCurrentStudent();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── PINNED APP BAR ────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Row(
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  'Rewards Store',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_currentStudent!.points} pts',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── HERO CARD ─────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeroCard()),

          // ── SEARCH BAR ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.neuBase,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.neuDark,
                      offset: Offset(4, 4),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-4, -4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search rewards...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFAABBAA),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Color(0xFFAABBAA),
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.neuBase,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // ── FILTER CHIPS ──────────────────────────────────────
          SliverToBoxAdapter(child: _buildFilterChips()),

          // ── SECTION HEADING ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Available Rewards',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── REWARDS LIST ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<List<RewardModel>>(
                stream: _rewardsController.getRewardsStream(
                  _currentStudent!.department,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 52,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading rewards',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _isLoading = true);
                              _loadCurrentStudent();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.neuBase,
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  List<RewardModel> rewards = snapshot.data ?? [];

                  if (_searchQuery.isNotEmpty) {
                    rewards =
                        rewards
                            .where(
                              (r) =>
                                  r.name.toLowerCase().contains(_searchQuery),
                            )
                            .toList();
                  }

                  if (_filter == _FilterType.canRedeem) {
                    rewards =
                        rewards
                            .where(
                              (r) =>
                                  r.stock > 0 &&
                                  _currentStudent!.points >= r.cost,
                            )
                            .toList();
                  } else if (_filter == _FilterType.outOfStock) {
                    rewards = rewards.where((r) => r.stock <= 0).toList();
                  }

                  if (rewards.isEmpty) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 48,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neuBase,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.neuDark,
                            offset: Offset(4, 4),
                            blurRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-4, -4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.card_giftcard_rounded,
                            size: 64,
                            color: AppColors.primary.withOpacity(0.35),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No rewards found'
                                : 'No rewards available yet',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try a different search term'
                                : 'Check back later!',
                            style: const TextStyle(
                              color: Color(0xFFAABBAA),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final startIndex = _currentPage * _itemsPerPage;
                  final endIndex = (startIndex + _itemsPerPage).clamp(
                    0,
                    rewards.length,
                  );
                  final paginatedRewards = rewards.sublist(
                    startIndex,
                    endIndex,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${startIndex + 1}–$endIndex of ${rewards.length} rewards',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ...paginatedRewards.map((r) => _buildRewardCard(r)),
                      _buildPaginationControls(rewards.length),
                    ],
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Redeem Bottom Sheet ────────────────────────────────────────────────────

class _RedeemBottomSheet extends StatelessWidget {
  final RewardModel reward;
  final StudentModel student;

  const _RedeemBottomSheet({required this.reward, required this.student});

  @override
  Widget build(BuildContext context) {
    final canAfford = student.points >= reward.cost;
    final hasImage = reward.imageUrl != null && reward.imageUrl!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.neuBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neuDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Confirm Redemption',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),

          // Reward row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: hasImage
                      ? _buildSheetImage(reward.imageUrl!)
                      : Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${reward.cost} points',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Points breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PointsInfo(
                    label: 'Your Points',
                    value: '${student.points}',
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.neuDark),
                Expanded(
                  child: _PointsInfo(label: 'Cost', value: '${reward.cost}'),
                ),
                Container(width: 1, height: 36, color: AppColors.neuDark),
                Expanded(
                  child: _PointsInfo(
                    label: 'After',
                    value: '${student.points - reward.cost}',
                    valueColor:
                        canAfford ? AppColors.primary : AppColors.error,
                  ),
                ),
              ],
            ),
          ),

          if (!canAfford) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'You need ${reward.cost - student.points} more points',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.neuDark),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed:
                      canAfford ? () => Navigator.of(context).pop(true) : null,
                  icon: const Icon(Icons.redeem_rounded, size: 18),
                  label: const Text(
                    'Confirm Redeem',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str =
            imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => const SizedBox(),
      errorWidget: (_, __, ___) => const SizedBox(),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────

class _PointsInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _PointsInfo({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _PagButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PagButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.neuBase : Colors.grey.shade200,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: AppColors.neuDark,
                    offset: Offset(3, 3),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-3, -3),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primary : Colors.grey.shade400,
        ),
      ),
    );
  }
}
