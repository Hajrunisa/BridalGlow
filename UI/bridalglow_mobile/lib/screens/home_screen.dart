import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:bridalglow_mobile/providers/auth_api_provider.dart';

import 'package:bridalglow_mobile/providers/interaction_provider.dart';

import 'package:bridalglow_mobile/providers/notification_provider.dart';

import 'package:bridalglow_mobile/providers/user_provider.dart';

import 'package:bridalglow_mobile/screens/dress_list_screen.dart';

import 'package:bridalglow_mobile/widgets/recommended_for_you_section.dart';

import 'package:bridalglow_mobile/screens/edit_profile_screen.dart';

import 'package:bridalglow_mobile/screens/login_screen.dart';

import 'package:bridalglow_mobile/screens/my_payments_screen.dart';

import 'package:bridalglow_mobile/screens/my_reservations_screen.dart';

import 'package:bridalglow_mobile/screens/my_reviews_screen.dart';

import 'package:bridalglow_mobile/screens/notification_inbox_screen.dart';

import 'package:bridalglow_mobile/models/user.dart';
import 'package:bridalglow_mobile/utils/session_storage.dart';



const _kPrimary = Color(0xFFC2778A);

const _kPrimaryLight = Color(0xFFFFF0F3);



ButtonStyle _homeActionStyle(Color backgroundColor) {

  return ElevatedButton.styleFrom(

    backgroundColor: backgroundColor,

    foregroundColor: Colors.white,

    minimumSize: const Size(double.infinity, 48),

    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),

    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

    elevation: 0,

  );

}



class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});



  @override

  State<HomeScreen> createState() => _HomeScreenState();

}



class _HomeScreenState extends State<HomeScreen> {

  NotificationProvider? _notificationProvider;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      _notificationProvider = context.read<NotificationProvider>();

      _notificationProvider!.addListener(_onNotificationUpdate);

      _notificationProvider!.connectRealtime();

      _notificationProvider!.refreshUnreadCount();

      context.read<InteractionProvider>().loadFavorites().catchError((_) {});

    });

  }



  @override

  void dispose() {

    _notificationProvider?.removeListener(_onNotificationUpdate);

    super.dispose();

  }



  void _onNotificationUpdate() {

    final notification = _notificationProvider?.lastPushedNotification;

    if (notification == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text('${notification.title}: ${notification.body}'),

        duration: const Duration(seconds: 4),

        behavior: SnackBarBehavior.floating,

      ),

    );

  }



  Future<void> _logout(BuildContext context) async {

    await context.read<NotificationProvider>().disconnectRealtime();

    await AuthApiProvider.logout();

    await SessionStorage.clearSession();

    if (context.mounted) {
      context.read<InteractionProvider>().clearFavorites();
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(

      MaterialPageRoute(builder: (_) => const LoginScreen()),

      (_) => false,

    );

  }



  Future<void> _openNotifications(BuildContext context) async {

    await Navigator.of(context).push(

      MaterialPageRoute(builder: (_) => const NotificationInboxScreen()),

    );

    if (!context.mounted) return;

    // Refresh badge count after returning from inbox

    context.read<NotificationProvider>().refreshUnreadCount();

  }



  @override

  Widget build(BuildContext context) {

    context.watch<UserProvider>();

    final user = UserProvider.currentUser;

    final unreadCount = context.watch<NotificationProvider>().unreadCount;



    return Scaffold(

      appBar: AppBar(

        title: const Text('BridalGlow'),

        actions: [

          // Notification bell with badge

          Stack(

            alignment: Alignment.center,

            children: [

              IconButton(

                icon: const Icon(Icons.notifications_outlined),

                tooltip: 'Notifications',

                onPressed: () => _openNotifications(context),

              ),

              if (unreadCount > 0)

                Positioned(

                  right: 6,

                  top: 6,

                  child: Container(

                    padding: const EdgeInsets.all(3),

                    decoration: const BoxDecoration(

                      color: _kPrimary,

                      shape: BoxShape.circle,

                    ),

                    constraints:

                        const BoxConstraints(minWidth: 18, minHeight: 18),

                    child: Text(

                      unreadCount > 99 ? '99+' : '$unreadCount',

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

          IconButton(

            icon: const Icon(Icons.logout),

            onPressed: () => _logout(context),

          ),

        ],

      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            _buildWelcomeSection(context, user),

            const SizedBox(height: 28),

            const RecommendedForYouSection(),

            const SizedBox(height: 28),

            Text(

              'Quick actions',

              style: Theme.of(context).textTheme.titleMedium?.copyWith(

                    fontWeight: FontWeight.w700,

                    color: const Color(0xFF1F2937),

                  ),

            ),

            const SizedBox(height: 14),

            ElevatedButton.icon(

              onPressed: () => Navigator.of(context).push(

                MaterialPageRoute(builder: (_) => const DressListScreen()),

              ),

              icon: const Icon(Icons.checkroom_outlined),

              label: const Text('Browse Dress Catalogue'),

              style: _homeActionStyle(_kPrimary),

            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(

              onPressed: () => Navigator.of(context).push(

                MaterialPageRoute(

                    builder: (_) => const MyReservationsScreen()),

              ),

              icon: const Icon(Icons.event_note_outlined),

              label: const Text('My Reservations'),

              style: _homeActionStyle(const Color(0xFF5B8DB8)),

            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(

              onPressed: () => Navigator.of(context).push(

                MaterialPageRoute(builder: (_) => const MyPaymentsScreen()),

              ),

              icon: const Icon(Icons.payments_outlined),

              label: const Text('My Payments'),

              style: _homeActionStyle(const Color(0xFF6B9080)),

            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(

              onPressed: () => Navigator.of(context).push(

                MaterialPageRoute(

                    builder: (_) => const MyReviewsScreen()),

              ),

              icon: const Icon(Icons.star_outline_rounded),

              label: const Text('My Reviews'),

              style: _homeActionStyle(_kPrimary),

            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(

              onPressed: () => _openNotifications(context),

              icon: Badge(

                isLabelVisible: unreadCount > 0,

                label: Text('$unreadCount'),

                backgroundColor: _kPrimary,

                child: const Icon(Icons.notifications_outlined),

              ),

              label: const Text('Notifications'),

              style: _homeActionStyle(const Color(0xFF7B6B8D)),

            ),

            const SizedBox(height: 10),

            ElevatedButton(

              onPressed: () => Navigator.of(context).push(

                MaterialPageRoute(builder: (_) => const ProfileScreen()),

              ),

              style: _homeActionStyle(const Color(0xFF374151)),

              child: const Text('My Profile'),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildWelcomeSection(BuildContext context, User? user) {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [

            _kPrimaryLight,

            Colors.white,

          ],

        ),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.04),

            blurRadius: 12,

            offset: const Offset(0, 3),

          ),

        ],

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Container(

            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(

              color: _kPrimary.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(12),

            ),

            child: const Icon(

              Icons.waving_hand_rounded,

              color: _kPrimary,

              size: 22,

            ),

          ),

          const SizedBox(width: 14),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  'Welcome, ${user?.fullName ?? 'Customer'}',

                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(

                        fontWeight: FontWeight.w700,

                        color: const Color(0xFF1F2937),

                        height: 1.2,

                      ),

                ),

                const SizedBox(height: 6),

                Text(

                  'Role: ${user?.roleName ?? ''}',

                  style: TextStyle(

                    fontSize: 14,

                    color: Colors.grey.shade600,

                    height: 1.3,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}



class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().getMyProfile();
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _kPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UserProvider>();
    final user = UserProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: AppBar(title: const Text('My Profile')),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: _kPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: _kPrimary.withValues(alpha: 0.15),
                    child: Text(
                      _initials(user.fullName),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _kPrimary.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Name',
                          value: user.fullName,
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        _infoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user.email,
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        _infoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Username',
                          value: user.username,
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        _infoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: user.phone ?? '-',
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        _infoRow(
                          icon: Icons.badge_outlined,
                          label: 'Role',
                          value: user.roleName,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                      style: _homeActionStyle(_kPrimary),
                      child: const Text('Edit Profile'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


