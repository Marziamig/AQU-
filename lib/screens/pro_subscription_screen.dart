import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final supabase = Supabase.instance.client;

class ProSubscriptionScreen extends StatefulWidget {
  const ProSubscriptionScreen({super.key});

  @override
  State<ProSubscriptionScreen> createState() => _ProSubscriptionScreenState();
}

class _ProSubscriptionScreenState extends State<ProSubscriptionScreen>
    with WidgetsBindingObserver {
  bool loading = false;
  bool isPro = false;

  Future<void> _startStripeCheckout(BuildContext context) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      loading = true;
    });

    try {
      final response =
          await supabase.functions.invoke('create-pro-checkout', body: {
        'user_id': user.id,
        'email': user.email,
      });

      final checkoutUrl = response.data['url'];

      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore pagamento: $e')),
      );
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _refreshProStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase
        .from('profiles')
        .select('is_pro')
        .eq('id', user.id)
        .single();

    if (!mounted) return;

    setState(() {
      isPro = profile['is_pro'] == true;
    });

    if (isPro) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _disableProMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Il tuo abbonamento PRO verrà disattivato.'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diventa PRO', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.workspace_premium,
              size: 80,
              color: Color(0xFFFFD84D),
            ),
            const SizedBox(height: 20),
            const Text(
              'Passa a PRO',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ricevi richieste di lavoro prima degli altri grazie al matching automatico.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                children: [
                  Text(
                    'Abbonamento PRO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '6,99 € / mese',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            /// ATTIVA PRO (disabilitato se già PRO)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPro ? Colors.grey : const Color(0xFFFFD84D),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: (loading || isPro)
                    ? null
                    : () => _startStripeCheckout(context),
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Attiva PRO',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            if (isPro) ...[
              const SizedBox(height: 15),

              /// DISATTIVA PRO
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _disableProMessage(context),
                  child: const Text(
                    'Disattiva PRO',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Il tuo abbonamento PRO verrà disattivato.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 10),
            const Text(
              'Puoi annullare l’abbonamento in qualsiasi momento.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
