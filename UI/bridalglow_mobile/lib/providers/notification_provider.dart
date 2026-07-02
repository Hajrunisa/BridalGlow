import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bridalglow_mobile/models/notification_model.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';
import 'package:bridalglow_mobile/services/notification_signalr_service.dart';

class NotificationProvider extends BaseProvider<NotificationModel> {
  NotificationProvider({NotificationSignalRService? signalRService})
      : _signalRService = signalRService ?? NotificationSignalRService(),
        super('Notifications');

  final NotificationSignalRService _signalRService;
  Timer? _pollingTimer;

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
    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: createHeaders());
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
    final uri =
        Uri.parse('${BaseProvider.baseUrl}Notifications/$id/read');
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
    _signalRService.onConnectionStateChanged = _onConnectionStateChanged;

    try {
      await _signalRService.connect();
    } catch (e) {
      debugPrint('SignalR connect failed: $e');
      _realtimeConnected = false;
      _startPollingFallback();
      notifyListeners();
    }
  }

  Future<void> disconnectRealtime() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _signalRService.onNotificationReceived = null;
    _signalRService.onConnectionStateChanged = null;
    await _signalRService.disconnect();
    _realtimeConnected = false;
    notifyListeners();
  }

  void _onConnectionStateChanged(bool connected) {
    _realtimeConnected = connected;
    if (connected) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    } else {
      _startPollingFallback();
    }
    notifyListeners();
  }

  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refreshUnreadCount();
    });
  }

  void _handleRealtimeNotification(NotificationModel notification) {
    _lastPushedNotification = notification;
    if (!notification.isRead) {
      _unreadCount = (_unreadCount + 1).clamp(0, 999999);
    }
    notifyListeners();
  }

  void clearLastPushed() => _lastPushedNotification = null;

  bool shouldShowPushBanner(NotificationModel notification) => true;
}
