import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  final _supabase = Supabase.instance.client;

  /// amountInEuro → esempio: 25.50
  Future<void> startPayment(
    double amountInEuro, {
    required String requestId,
    required String requestType,
  }) async {
    try {
      final int amountInCents = (amountInEuro * 100).round();

      final response = await _supabase.functions.invoke(
        'create-payment',
        body: {
          'amount': amountInCents,
          'currency': 'eur',
          'request_id': requestId,
          'request_type': requestType,
        },
      );

      final data = response.data; // ✅ FIX

      // 🔒 pagamento già esistente
      if (response.status == 400 &&
          data != null &&
          data['error'] == "Payment already exists for this request") {
        throw Exception("PAYMENT_ALREADY_EXISTS");
      }

      if (data == null || data['clientSecret'] == null) {
        throw Exception("PAYMENT_INTENT_ERROR");
      }

      final String clientSecret = data['clientSecret'];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Aqui',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw Exception("PAYMENT_CANCELED");
      }

      if (e.error.code == FailureCode.Failed) {
        throw Exception("PAYMENT_FAILED");
      }

      throw Exception("STRIPE_ERROR");
    } on FunctionException catch (e) {
      throw Exception("BACKEND_ERROR: ${e.details}");
    } catch (e) {
      throw Exception("PAYMENT_UNKNOWN_ERROR");
    }
  }
}
