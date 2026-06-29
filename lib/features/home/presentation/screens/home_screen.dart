import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../admin/domain/entities/admin_announcement.dart';
import '../../../admin/domain/entities/admin_event.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _announcementsController = PageController();
  int _currentAnnouncementPage = 0;

  @override
  void initState() {
    super.initState();
    // Fetch fresh data when entering home screen
    Future.microtask(() {
      ref.read(homeProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _announcementsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final homeState = ref.watch(homeProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    // Get unread notification count
    final unreadNotificationsCount = notificationsAsync.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );

    // Retrieve user name
    final String firstName = authState is AuthAuthenticated
        ? authState.user.firstName
        : 'Student';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).load(),
        color: AppTheme.secondary,
        backgroundColor: AppTheme.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── HEADER ──
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(
                  left: AppTheme.spaceLG,
                  right: AppTheme.spaceLG,
                  top: 50.0,
                  bottom: AppTheme.spaceMD,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppTheme.radiusXL),
                    bottomRight: Radius.circular(AppTheme.radiusXL),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primary.withAlpha(40),
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          Text(
                            firstName,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Federal University Dutse',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => context.push(AppRoutes.notifications),
                        ),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadNotificationsCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── ANNOUNCEMENTS CAROUSEL ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            color: AppTheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recent Announcements',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    if (homeState.isLoading)
                      const SizedBox(
                        height: 160,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (homeState.announcements.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
                        child: Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                            border: Border.all(
                              color: Colors.white.withAlpha(20),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.campaign_outlined,
                                color: Colors.white.withAlpha(40),
                                size: 48,
                              ),
                              const SizedBox(height: AppTheme.spaceSM),
                              Text(
                                'No recent announcements',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 160,
                            child: PageView.builder(
                              controller: _announcementsController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentAnnouncementPage = index;
                                });
                              },
                              itemCount: homeState.announcements.length,
                              itemBuilder: (context, index) {
                                final announcement = homeState.announcements[index];
                                return _buildAnnouncementCard(announcement);
                              },
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceSM),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              homeState.announcements.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentAnnouncementPage == index ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentAnnouncementPage == index
                                      ? AppTheme.secondary
                                      : Colors.white.withAlpha(60),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // ── QUICK ACTIONS ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          color: AppTheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppTheme.spaceMD,
                      mainAxisSpacing: AppTheme.spaceMD,
                      childAspectRatio: 1.4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildActionCard(
                          context,
                          title: 'Campus Map',
                          desc: 'Find lecture halls',
                          icon: Icons.map_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00695C), Color(0xFF00897B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.push(AppRoutes.map),
                        ),
                        _buildActionCard(
                          context,
                          title: 'Marketplace',
                          desc: 'Buy & sell items',
                          icon: Icons.shopping_bag_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.push(AppRoutes.marketplace),
                        ),
                        _buildActionCard(
                          context,
                          title: 'My Schedule',
                          desc: 'Manage weekly slots',
                          icon: Icons.calendar_month_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD84315), Color(0xFFFF8A65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.push(AppRoutes.profile),
                        ),
                        _buildActionCard(
                          context,
                          title: 'SOS Help',
                          desc: 'Emergency contact',
                          icon: Icons.warning_amber_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC62828), Color(0xFFEF5350)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.push(AppRoutes.sos),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── UPCOMING EVENTS ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      color: AppTheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upcoming Events',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            if (homeState.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (homeState.events.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceLG),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      border: Border.all(
                        color: Colors.white.withAlpha(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          color: Colors.white.withAlpha(40),
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        Text(
                          'No upcoming events',
                          style: TextStyle(
                            color: Colors.white.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = homeState.events[index];
                      return _buildEventItem(event);
                    },
                    childCount: homeState.events.length,
                  ),
                ),
              ),

            // Bottom space helper
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(AdminAnnouncement announcement) {
    // Beautiful dynamic card with custom gradients
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withAlpha(220),
            const Color(0xFF2E0827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(30),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.campaign,
              size: 120,
              color: Colors.white.withAlpha(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CAMPUS DIRECT',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      announcement.timestamp.toString().substring(11, 16),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  announcement.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spaceXS),
                Expanded(
                  child: Text(
                    announcement.content,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  icon,
                  size: 64,
                  color: Colors.white.withAlpha(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          desc,
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(AdminEvent event) {
    final months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final String monthStr = event.timestamp.month > 0 && event.timestamp.month <= 12
        ? months[event.timestamp.month - 1]
        : 'JUN';
    final String dayStr = event.timestamp.day.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: Colors.white.withAlpha(10),
        ),
      ),
      child: Row(
        children: [
          // Date block widget
          Container(
            width: 65,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(30),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLG),
                bottomLeft: Radius.circular(AppTheme.radiusLG),
              ),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withAlpha(10),
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayStr,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  monthStr,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM, horizontal: AppTheme.spaceXS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.timestamp.toString().substring(11, 16),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
