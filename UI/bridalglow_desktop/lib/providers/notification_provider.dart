import 'dart:convert';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_desktop/models/notification.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';
import 'package:bridalglow_desktop/providers/notification_refresh_coordinator.dart';
import 'package:bridalglow_desktop/services/notification_signalr_service.dart';

class NotificationProvider extends BaseProvider<NotificationModel> {
  NotificationProvider({
    required NotificationRefreshCoordinator refreshCoordinator,
    NotificationSignalRService? signalRService,
  })  : _refreshCoordinator = refreshCoordinator,
        _signalRService = signalRService ?? NotificationSignalRService(),
        super('Notifications');

  final NotificationRefreshCoordinator _refreshCoordinator;
  final NotificationSignalRService _signalRService;

  int _unreadCount = 0;
  bool _realtimeConnected = false;
  NotificationModel? _lastPushedNotification;

  int get unreadCount => _unreadCount;
  bool get realtimeConnected => _realtimeConnected;
  NotificationModel? get lastPushedNotification => _lastPushedNotification;

  @override
  NotificationModel fromJson(dynamic json) =>
      NotificationModel.fromJson(json as Map<String, dynamic>);

  Future<List<NotificationModel>> getMyNotifications({bool? isRead}) async {
    var url =
        '${BaseProvider.baseUrl}Notifications?pageSize=50&includeTotalCount=false';
    if (isRead != null) url += '&isRead=$isRead';
    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<NotificationModel> markAsRead(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Notifications/$id/read');
    final response = await http.post(uri, headers: createHeaders());
    if (isValidResponse(response)) {
      await refreshUnreadCount();
      return NotificationModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to mark notification as read');
  }

  Future<void> markAllAsRead() async {
    final uri = Uri.parse('${BaseProvider.baseUrl}Notifications/read-all');
    final response = await http.post(uri, headers: createHeaders());
    if (response.statusCode == 204 || response.statusCode < 299) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }
    throw Exception('Failed to mark all notifications as read');
  }

  Future<void> refreshUnreadCount() async {
    try {
      final uri = Uri.parse(
          '${BaseProvider.baseUrl}Notifications?pageSize=1&includeTotalCount=true&isRead=false');
      final response = await http.get(uri, headers: createHeaders());
      if (isValidResponse(response)) {
        final data = jsonDecode(response.body);
        _unreadCount = data['totalCount'] as int? ?? 0;
        notifyListeners();
      }
    } catch (_) {
      _unreadCount = 0;
      notifyListeners();
    }
  }

  Future<void> connectRealtime() async {
    _signalRService.onNotificationReceived = _handleRealtimeNotification;
    _signalRService.onConnectionStateChanged = (connected) {
      _realtimeConnected = connected;
      notifyListeners();
    };

    try {
      await _signalRService.connect();
    } catch (e) {
      debugPrint('SignalR connect failed: $e');
      _realtimeConnected = false;
      notifyListeners();
    }
  }

  Future<void> disconnectRealtime() async {
    _signalRService.onNotificationReceived = null;
    _signalRService.onConnectionStateChanged = null;
    await _signalRService.disconnect();
    _realtimeConnected = false;
    notifyListeners();
  }

  void _handleRealtimeNotification(NotificationModel notification) {
    scheduleMicrotask(() async {
      _lastPushedNotification = notification;
      _refreshCoordinator.requestRefresh(
        relatedEntityType: notification.relatedEntityType,
      );
      notifyListeners();

      // Keep badge in sync with the server count after realtime delivery.
      await refreshUnreadCount();
    });
  }

  void clearLastPushed() => _lastPushedNotification = null;

  bool shouldShowToast(NotificationModel notification) {
    switch (notification.type) {
      case 1:
      case 2:
      case 3:
      case 4:
      case 8:
      case 9:
      case 10:
      case 11:
        return true;
      default:
        return notification.relatedEntityType == 'RentalReservation' ||
            notification.relatedEntityType == 'TryOnReservation' ||
            notification.relatedEntityType == 'Payment' ||
            notification.relatedEntityType == 'Refund';
    }
  }
}
