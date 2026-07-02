import 'dart:async';
import 'dart:convert';



import 'package:flutter/foundation.dart';

import 'package:signalr_netcore/signalr_client.dart';

import 'package:bridalglow_desktop/models/notification.dart';

import 'package:bridalglow_desktop/providers/auth_provider.dart';

import 'package:bridalglow_desktop/providers/base_provider.dart';



/// SignalR client for `/hubs/notifications` (Korak 4 backend).

class NotificationSignalRService {

  HubConnection? _connection;

  void Function(NotificationModel notification)? onNotificationReceived;

  void Function(bool connected)? onConnectionStateChanged;



  bool get isConnected =>

      _connection?.state == HubConnectionState.Connected;



  String _resolveHubUrl() {

    const dartDefine = String.fromEnvironment('SIGNALR_HUB_URL');

    if (dartDefine.isNotEmpty) return dartDefine;



    try {

      final fromEnv = BaseProvider.hubUrlOverride;

      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    } catch (_) {}



    return '${BaseProvider.serverOrigin}/hubs/notifications';

  }



  Future<void> connect() async {

    final token = AuthProvider.accessToken;

    if (token == null || token.isEmpty) return;



    await disconnect();



    final hubUrl = _resolveHubUrl();

    _connection = HubConnectionBuilder()

        .withUrl(

          hubUrl,

          options: HttpConnectionOptions(

            accessTokenFactory: () async => AuthProvider.accessToken ?? token,

          ),

        )

        .withAutomaticReconnect()

        .build();



    _connection!.on('ReceiveNotification', (arguments) {

      _dispatchNotification(arguments);

    });



    _connection!.onclose(({error}) {

      _emitConnectionState(false);

    });



    _connection!.onreconnected(({connectionId}) {

      _emitConnectionState(true);

    });



    await _connection!.start();

    _emitConnectionState(true);

  }



  void _dispatchNotification(List<Object?>? arguments) {

    if (arguments == null || arguments.isEmpty) return;



    try {

      final notification = NotificationModel.fromJson(

        _parsePayload(arguments.first),

      );



      // SignalR callbacks can arrive off the UI isolate on desktop; marshal back.

      scheduleMicrotask(() {

        onNotificationReceived?.call(notification);

      });

    } catch (e, stack) {

      debugPrint('SignalR notification parse failed: $e\n$stack');

    }

  }



  Map<String, dynamic> _parsePayload(Object? raw) {

    if (raw is String) {

      final decoded = jsonDecode(raw);

      if (decoded is Map) {

        return Map<String, dynamic>.from(decoded);

      }

      throw FormatException('Expected JSON object, got ${decoded.runtimeType}');

    }



    if (raw is Map) {

      return Map<String, dynamic>.from(raw);

    }



    throw FormatException('Unexpected SignalR payload type: ${raw.runtimeType}');

  }



  void _emitConnectionState(bool connected) {

    scheduleMicrotask(() {

      onConnectionStateChanged?.call(connected);

    });

  }



  Future<void> disconnect() async {

    final connection = _connection;

    _connection = null;

    if (connection != null) {

      try {

        await connection.stop();

      } catch (_) {}

    }

    _emitConnectionState(false);

  }

}


