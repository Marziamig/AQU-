import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

class CreateAdScreen extends StatefulWidget {
  const CreateAdScreen({super.key});

  @override
  State<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String serviceType = 'Pulizie';
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

  Future<void> _submitAd() async {
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
      'service_type': serviceType,
      'description': descriptionController.text,
      'price': double.tryParse(priceController.text) ?? 0,
      'created_at': DateTime.now().toIso8601String(),
      'lat': pos.latitude,
      'lng': pos.longitude,
      'ad_type': 'offer',
      'status': 'open',
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Crea annuncio', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: serviceType,
                items: const [
                  DropdownMenuItem(value: 'Pulizie', child: Text('Pulizie')),
                  DropdownMenuItem(
                      value: 'Babysitting', child: Text('Babysitting')),
                  DropdownMenuItem(
                      value: 'Infermiere', child: Text('Infermiere')),
                  DropdownMenuItem(
                      value: 'Assistenza', child: Text('Assistenza anziani')),
                  DropdownMenuItem(value: 'Lezioni', child: Text('Lezioni')),
                  DropdownMenuItem(
                      value: 'Chef a domicilio',
                      child: Text('Chef a domicilio')),
                  DropdownMenuItem(value: 'Sarta', child: Text('Sarta')),
                  DropdownMenuItem(
                      value: 'Lavori', child: Text('Lavori / Manutenzione')),
                  DropdownMenuItem(
                      value: 'Parrucchiere', child: Text('Parrucchiere')),
                  DropdownMenuItem(
                      value: 'Estetista', child: Text('Estetista')),
                  DropdownMenuItem(value: 'Altro', child: Text('Altro')),
                ],
                onChanged: (v) => setState(() => serviceType = v!),
                decoration: const InputDecoration(labelText: 'Tipo servizio'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration:
                    const InputDecoration(labelText: 'Descrizione servizio'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Inserisci una descrizione' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Prezzo (€)'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Inserisci un prezzo' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD84D),
                  foregroundColor: Colors.black,
                ),
                onPressed: loading ? null : _submitAd,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pubblica annuncio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
