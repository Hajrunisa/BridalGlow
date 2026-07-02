import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/user.dart';
import 'package:bridalglow_desktop/providers/auth_api_provider.dart';
import 'package:bridalglow_desktop/providers/auth_provider.dart';
import 'package:bridalglow_desktop/providers/user_provider.dart';
import 'package:bridalglow_desktop/screens/dashboard_screen.dart';
import 'package:bridalglow_desktop/screens/availability_screen.dart';
import 'package:bridalglow_desktop/screens/dress_price_rules_screen.dart';
import 'package:bridalglow_desktop/screens/try_on_reservations_screen.dart';
import 'package:bridalglow_desktop/screens/rental_reservations_screen.dart';
import 'package:bridalglow_desktop/screens/finance_screen.dart';
import 'package:bridalglow_desktop/screens/dress_category_list_screen.dart';
import 'package:bridalglow_desktop/screens/dress_list_screen.dart';
import 'package:bridalglow_desktop/screens/dress_tag_list_screen.dart';
import 'package:bridalglow_desktop/screens/login_screen.dart';
import 'package:bridalglow_desktop/screens/maintenance_screen.dart';
import 'package:bridalglow_desktop/screens/reports_screen.dart';
import 'package:bridalglow_desktop/screens/profile_screen.dart';
import 'package:bridalglow_desktop/screens/reviews_screen.dart';
import 'package:bridalglow_desktop/providers/notification_provider.dart';
import 'package:bridalglow_desktop/screens/notifications_screen.dart';
import 'package:bridalglow_desktop/screens/users_list_screen.dart';

const _kPrimary = Color(0xFFC2778A);

class MasterScreen extends StatefulWidget {
  final User user;

  const MasterScreen({super.key, required this.user});

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  int _selectedIndex = 0;
  NotificationProvider? _notificationProvider;
  final Set<int> _toastedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationProvider = context.read<NotificationProvider>();
      _notificationProvider!.addListener(_onNotificationUpdate);
      _notificationProvider!.connectRealtime();
      _notificationProvider!.refreshUnreadCount();
    });
  }

  @override
  void dispose() {
    _notificationProvider?.removeListener(_onNotificationUpdate);
    _notificationProvider?.disconnectRealtime();
    super.dispose();
  }

  int _notificationsNavIndex(List<_NavItem> navItems) =>
      navItems.indexWhere((item) => item.label == 'Notifications');

  void _openNotifications(List<_NavItem> navItems) {
    final index = _notificationsNavIndex(navItems);
    if (index < 0) return;
    setState(() => _selectedIndex = index);
  }

  void _onNotificationUpdate() {
    final provider = _notificationProvider;
    if (provider == null || !mounted) return;

    scheduleMicrotask(() {
      if (!mounted) return;

      final notification = provider.lastPushedNotification;
      if (notification == null || !provider.shouldShowToast(notification)) {
        return;
      }
      if (_toastedNotificationIds.contains(notification.id)) {
        return;
      }
      _toastedNotificationIds.add(notification.id);

      final navItems = _buildNavItems();
      final notificationsIndex = _notificationsNavIndex(navItems);
      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text('${notification.title}: ${notification.body}'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              messenger.hideCurrentSnackBar();
              if (notificationsIndex >= 0) {
                setState(() => _selectedIndex = notificationsIndex);
              }
            },
          ),
        ),
      );
    });
  }

  /// Build pages and destinations in sync so indices always match.
  /// The Users page is only included for Admin users.
  List<_NavItem> _buildNavItems() {
    return [
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        page: DashboardScreen(user: widget.user),
      ),
      _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications_rounded,
        label: 'Notifications',
        page: const NotificationsScreen(),
      ),
      _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
        page: const ProfileScreen(),
      ),
      if (widget.user.isAdmin)
        _NavItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people_rounded,
          label: 'Users',
          page: const UsersListScreen(),
        ),
      _NavItem(
        icon: Icons.category_outlined,
        activeIcon: Icons.category_rounded,
        label: 'Categories',
        page: const DressCategoryListScreen(),
      ),
      _NavItem(
        icon: Icons.sell_outlined,
        activeIcon: Icons.sell_rounded,
        label: 'Tags',
        page: const DressTagListScreen(),
      ),
      _NavItem(
        icon: Icons.checkroom_outlined,
        activeIcon: Icons.checkroom_rounded,
        label: 'Dresses',
        page: const DressListScreen(),
      ),
      _NavItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_rounded,
        label: 'Availability',
        page: const AvailabilityScreen(),
      ),
      _NavItem(
        icon: Icons.price_change_outlined,
        activeIcon: Icons.price_change_rounded,
        label: 'Pricing',
        page: const DressPriceRulesScreen(),
      ),
      _NavItem(
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note_rounded,
        label: 'Try-On',
        page: const TryOnReservationsScreen(),
      ),
      _NavItem(
        icon: Icons.weekend_outlined,
        activeIcon: Icons.weekend_rounded,
        label: 'Rentals',
        page: const RentalReservationsScreen(),
      ),
      _NavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Finance',
        page: const FinanceScreen(),
      ),
      _NavItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics_rounded,
        label: 'Reports',
        page: const ReportsScreen(),
      ),
      _NavItem(
        icon: Icons.star_border_rounded,
        activeIcon: Icons.star_rounded,
        label: 'Reviews',
        page: const ReviewsScreen(),
      ),
      _NavItem(
        icon: Icons.build_outlined,
        activeIcon: Icons.build_rounded,
        label: 'Maintenance',
        page: const MaintenanceScreen(),
      ),
    ];
  }

  Future<void> _logout() async {
    await _notificationProvider?.disconnectRealtime();
    await AuthApiProvider.logout();
    AuthProvider.accessToken = null;
    AuthProvider.refreshToken = null;
    UserProvider.currentUser = null;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _buildNavItems();

    // Clamp index in case the list shrinks (e.g. role change between builds)
    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      body: Row(
        children: [
          _buildNavigationRail(navItems),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: navItems[_selectedIndex].page),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(List<_NavItem> navItems) {
    return Container(
      width: 80,
      color: Colors.white,
      child: Column(
        children: [
          _buildRailHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: navItems.length,
              itemBuilder: (context, index) =>
                  _buildRailDestination(navItems[index], index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: _buildLogoutButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildRailDestination(_NavItem item, int index) {
    final selected = _selectedIndex == index;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: selected
                      ? BoxDecoration(
                          color: _kPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        )
                      : null,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: selected ? 24 : 22,
                    color: selected ? _kPrimary : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _kPrimary : Colors.grey.shade500,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailHeader() {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimary, Color(0xFFD4889A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.diamond_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          const Text(
            'BridalGlow',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _kPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: 'Notifications',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => _openNotifications(_buildNavItems()),
                  icon: const Icon(Icons.notifications_outlined),
                  color: _kPrimary,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
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
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Tooltip(
      message: 'Logout',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _showLogoutDialog,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            SizedBox(width: 10),
            Text(
              'Confirm Logout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from your account?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

/// Simple data class binding a nav destination to its page widget.
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget page;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.page,
  });
}
