import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController detailController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  bool loading = false;

  Future<String?> _getUserName() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final res = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .single();

    return res['full_name'];
  }

  Future<void> _submitService() async {
    if (!_formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    final permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => loading = false);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final userName = await _getUserName();

    await supabase.from('ads').insert({
      'user_id': user.id,
      'user_name': userName,
      'service_type': 'Servizio',
      'from_location': detailController.text,
      'price': double.tryParse(priceController.text) ?? 0,
      'created_at': DateTime.now().toIso8601String(),
      'lat': pos.latitude,
      'lng': pos.longitude,
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Richiedi servizio',
            style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D), // ⭐ GIALLO HOME
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: detailController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Dettaglio servizio',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Inserisci un dettaglio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prezzo massimo (€)',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Inserisci un prezzo' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD84D),
                  foregroundColor: Colors.black,
                ),
                onPressed: loading ? null : _submitService,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pubblica richiesta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
