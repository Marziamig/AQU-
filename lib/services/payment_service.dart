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

      // 🔒 pagamento già esistente
      if (response.status == 400 &&
          response.data != null &&
          response.data['error'] == "Payment already exists for this request") {
        throw Exception("PAYMENT_ALREADY_EXISTS");
      }

      if (response.data == null || response.data['clientSecret'] == null) {
        throw Exception("PAYMENT_INTENT_ERROR");
      }

      final String clientSecret = response.data['clientSecret'];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Aqui',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      // ❗ utente chiude PaymentSheet
      if (e.error.code == FailureCode.Canceled) {
        throw Exception("PAYMENT_CANCELED");
      }

      // ❗ carta rifiutata
      if (e.error.code == FailureCode.Failed) {
        throw Exception("PAYMENT_FAILED");
      }

      // ❗ errore sconosciuto Stripe
      throw Exception("STRIPE_ERROR");
    } on FunctionException catch (e) {
      // errore Edge Function Supabase
      throw Exception("BACKEND_ERROR: ${e.details}");
    } catch (e) {
      // fallback sicurezza
      throw Exception("PAYMENT_UNKNOWN_ERROR");
    }
  }
}
