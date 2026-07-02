import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/notification_model.dart';
import 'package:bridalglow_mobile/providers/notification_provider.dart';
import 'package:bridalglow_mobile/screens/my_reviews_screen.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  String? _error;
  NotificationProvider? _notificationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationProvider = context.read<NotificationProvider>();
      _notificationProvider!.addListener(_onProviderUpdate);
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _notificationProvider?.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    final pushed = _notificationProvider?.lastPushedNotification;
    if (pushed == null || !mounted) return;
    if (_notifications.any((n) => n.id == pushed.id)) {
      _notificationProvider?.clearLastPushed();
      return;
    }
    setState(() => _notifications.insert(0, pushed));
    _notificationProvider?.clearLastPushed();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<NotificationProvider>();
      final items = await provider.getMyNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _loading = false;
      });
      await provider.refreshUnreadCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    try {
      final provider = context.read<NotificationProvider>();
      final updated = await provider.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx != -1) _notifications[idx] = updated;
      });
      await provider.refreshUnreadCount();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await context.read<NotificationProvider>().markAllAsRead();
      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('dd.MM.yyyy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (!_loading && unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC2778A),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: _notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            return _NotificationTile(
                              notification: n,
                              formattedTime: _formatTime(n.createdAtUtc),
                              onMarkRead: n.isRead ? null : () => _markAsRead(n),
                              onNavigate: n.type == 6
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const MyReviewsScreen()),
                                      )
                                  : null,
                            );
                          },
                        ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none_outlined,
                  size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No notifications',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'You will receive notifications when your\nreservation status changes.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Error loading notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String formattedTime;
  final VoidCallback? onMarkRead;
  final VoidCallback? onNavigate;

  const _NotificationTile({
    required this.notification,
    required this.formattedTime,
    this.onMarkRead,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFFFF0F3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? const Color(0xFFD4A5A5)
              : Colors.grey[200]!,
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: const Color(0xFFD4A5A5).withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (onMarkRead != null) onMarkRead!();
          if (onNavigate != null) onNavigate!();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with unread dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isUnread
                        ? const Color(0xFFD4A5A5).withValues(alpha: 0.2)
                        : Colors.grey[100],
                    child: Icon(
                      _iconForType(notification.type),
                      color: isUnread
                          ? const Color(0xFFC2778A)
                          : Colors.grey[500],
                      size: 22,
                    ),
                  ),
                  if (isUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC2778A),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (onNavigate != null)
                            TextButton.icon(
                              onPressed: () {
                                if (onMarkRead != null) onMarkRead!();
                                onNavigate!();
                              },
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 14),
                              label: const Text('View',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    const Color(0xFFC2778A),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onMarkRead,
                            child: Row(
                              children: [
                                Icon(Icons.done,
                                    size: 14,
                                    color: const Color(0xFFC2778A)),
                                const SizedBox(width: 4),
                                Text(
                                  'Mark as read',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFC2778A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(int type) {
    switch (type) {
      case 1:
        return Icons.event_available_outlined;
      case 2:
        return Icons.check_circle_outline;
      case 3:
        return Icons.cancel_outlined;
      case 4:
        return Icons.money_off_outlined;
      case 5:
        return Icons.alarm_outlined;
      case 6:
        return Icons.rate_review_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
