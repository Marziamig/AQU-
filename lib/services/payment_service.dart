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

      // 🔒 Gestione pagamento già effettuato
      if (response.status == 400 &&
          response.data != null &&
          response.data['error'] == "Payment already completed") {
        throw Exception("ALREADY_PAID");
      }

      if (response.data == null || response.data['clientSecret'] == null) {
        throw Exception("Errore creazione PaymentIntent");
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
      throw Exception(
        "Pagamento annullato o errore Stripe: ${e.error.localizedMessage}",
      );
    } catch (e) {
      rethrow;
    }
  }
}
