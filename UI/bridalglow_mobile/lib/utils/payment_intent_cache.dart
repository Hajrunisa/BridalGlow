import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:bridalglow_mobile/models/payment.dart';

/// Persists Stripe PaymentIntent credentials locally so a customer can resume
/// payment when a reservation is already in AwaitingPayment status.
class PaymentIntentCache {
  static const _prefix = 'payment_intent_';

  static String _key(int rentalReservationId) => '$_prefix$rentalReservationId';

  static Future<void> save(
    int rentalReservationId,
    PaymentIntentData data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(rentalReservationId), jsonEncode(data.toJson()));
  }

  static Future<PaymentIntentData?> load(int rentalReservationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(rentalReservationId));
    if (raw == null || raw.isEmpty) return null;
    return PaymentIntentData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clear(int rentalReservationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(rentalReservationId));
  }
}
