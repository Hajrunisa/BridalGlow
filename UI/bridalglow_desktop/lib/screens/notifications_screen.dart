import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/notification.dart';
import 'package:bridalglow_desktop/providers/notification_provider.dart';

const _kPrimary = Color(0xFFC2778A);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
    if (pushed == null) return;
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
    return DateFormat('dd.MM.yyyy HH:mm').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_outlined, color: _kPrimary),
              const SizedBox(width: 12),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              if (!_loading && unreadCount > 0)
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all read'),
                ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _notifications.isEmpty
                        ? const Center(child: Text('No notifications yet.'))
                        : ListView.separated(
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final n = _notifications[index];
                              return _NotificationCard(
                                notification: n,
                                formattedTime: _formatTime(n.createdAtUtc),
                                onMarkRead:
                                    n.isRead ? null : () => _markAsRead(n),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String formattedTime;
  final VoidCallback? onMarkRead;

  const _NotificationCard({
    required this.notification,
    required this.formattedTime,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return Material(
      color: isUnread ? const Color(0xFFFFF0F3) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onMarkRead,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnread ? _kPrimary : Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: isUnread ? _kPrimary : Colors.grey,
              ),
              const SizedBox(width: 12),
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
                              fontWeight:
                                  isUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(notification.body),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
