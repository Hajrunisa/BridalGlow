import 'package:flutter/foundation.dart';

/// Broadcasts refresh requests to operational screens after real-time events.
class NotificationRefreshCoordinator extends ChangeNotifier {
  int _generation = 0;
  String? _lastRelatedEntityType;

  int get generation => _generation;
  String? get lastRelatedEntityType => _lastRelatedEntityType;

  void requestRefresh({String? relatedEntityType}) {
    _lastRelatedEntityType = relatedEntityType;
    _generation++;
    notifyListeners();
  }

  static bool affectsRental(String? entityType) =>
      entityType == null || entityType == 'RentalReservation';

  static bool affectsTryOn(String? entityType) =>
      entityType == null || entityType == 'TryOnReservation';

  static bool affectsFinance(String? entityType) =>
      entityType == null ||
      entityType == 'Payment' ||
      entityType == 'Refund';

  static bool affectsReviews(String? entityType) =>
      entityType == null || entityType == 'Review';
}
