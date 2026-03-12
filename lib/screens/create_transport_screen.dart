import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

class CreateTransportScreen extends StatefulWidget {
  const CreateTransportScreen({super.key});

  @override
  State<CreateTransportScreen> createState() => _CreateTransportScreenState();
}

class _CreateTransportScreenState extends State<CreateTransportScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController capacityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  DateTime? selectedDate;

  bool loading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _submitTransport() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una data')),
      );
      return;
    }

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

    final profile = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .single();

    final userName = profile['full_name'];

    await supabase.from('ads').insert({
      'user_id': user.id,
      'user_name': userName,
      'service_type': 'Trasporti',
      'from_location': fromController.text,
      'to_location': toController.text,
      'capacity': capacityController.text,
      'price': double.tryParse(priceController.text) ?? 0,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'transport_date': selectedDate!.toIso8601String(),
      'ad_type': 'offer',
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo Trasporto',
            style: TextStyle(color: Colors.black)),
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
              TextFormField(
                controller: fromController,
                decoration: const InputDecoration(labelText: 'Partenza'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: toController,
                decoration: const InputDecoration(labelText: 'Destinazione'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Data trasporto',
                    ),
                    controller: TextEditingController(
                      text: selectedDate == null
                          ? ''
                          : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    ),
                    validator: (_) =>
                        selectedDate == null ? 'Obbligatorio' : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capacità / spazio disponibile',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Prezzo (€)'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD84D),
                  foregroundColor: Colors.black,
                ),
                onPressed: loading ? null : _submitTransport,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pubblica trasporto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
