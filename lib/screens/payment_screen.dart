import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';

final supabase = Supabase.instance.client;

class PaymentScreen extends StatefulWidget {
  final String requestId;
  final double baseAmount;
  final double percentFee;
  final double fixedFee;
  final double totalAmount;
  final String? requesterId;

  const PaymentScreen({
    super.key,
    required this.requestId,
    required this.baseAmount,
    required this.percentFee,
    required this.fixedFee,
    required this.totalAmount,
    this.requesterId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  bool loading = false;

  Future<void> _startPayment() async {
    setState(() => loading = true);

    try {
      await _paymentService.startPayment(
        widget.totalAmount,
        requestId: widget.requestId,
        requestType: 'service',
      );

      await supabase
          .from('payment_requests')
          .update({'status': 'paid'}).eq('id', widget.requestId);

      if (widget.requesterId != null) {
        await supabase.from('notifications').insert({
          'user_id': widget.requesterId,
          'title': 'Pagamento effettuato',
          'body':
              'Il pagamento di €${widget.baseAmount.toStringAsFixed(2)} è stato effettuato.',
          'reference_id': widget.requestId,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento completato')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il pagamento')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double managementCost = widget.percentFee + widget.fixedFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pagamento',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _priceRow(
                    'Servizio',
                    '€ ${widget.baseAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 10),
                  _priceRow(
                    'Costo di gestione piattaforma AQUÍ',
                    '€ ${managementCost.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 30),
                  _priceRow(
                    'Totale pagamento',
                    '€ ${widget.totalAmount.toStringAsFixed(2)}',
                    bold: true,
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD84D),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Procedi al pagamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
