import 'package:signalr_netcore/signalr_client.dart';
import 'package:bridalglow_mobile/models/notification_model.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';

class NotificationSignalRService {
  HubConnection? _connection;
  void Function(NotificationModel notification)? onNotificationReceived;
  void Function(bool connected)? onConnectionStateChanged;

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  String _resolveHubUrl() {
    const dartDefine = String.fromEnvironment('SIGNALR_HUB_URL');
    if (dartDefine.isNotEmpty) return dartDefine;

    final override = BaseProvider.hubUrlOverride;
    if (override != null && override.isNotEmpty) return override;

    return '${BaseProvider.serverOrigin}/hubs/notifications';
  }

  Future<void> connect() async {
    final token = AuthProvider.accessToken;
    if (token == null || token.isEmpty) return;

    await disconnect();

    _connection = HubConnectionBuilder()
        .withUrl(
          _resolveHubUrl(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            skipNegotiation: false,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('ReceiveNotification', (arguments) {
      if (arguments == null || arguments.isEmpty) return;
      final raw = arguments[0];
      if (raw is! Map) return;
      onNotificationReceived?.call(
        NotificationModel.fromJson(Map<String, dynamic>.from(raw)),
      );
    });

    _connection!.onclose(({error}) {
      onConnectionStateChanged?.call(false);
    });

    _connection!.onreconnected(({connectionId}) {
      onConnectionStateChanged?.call(true);
    });

    await _connection!.start();
    onConnectionStateChanged?.call(true);
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        await connection.stop();
      } catch (_) {}
    }
    onConnectionStateChanged?.call(false);
  }
}
