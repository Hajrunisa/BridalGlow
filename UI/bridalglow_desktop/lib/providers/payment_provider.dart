import 'package:bridalglow_desktop/models/payment.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';

class PaymentProvider extends BaseProvider<Payment> {
  PaymentProvider() : super('Finance/payments');

  @override
  Payment fromJson(dynamic json) =>
      Payment.fromJson(json as Map<String, dynamic>);
}
