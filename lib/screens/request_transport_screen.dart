import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class RequestTransportScreen extends StatefulWidget {
  const RequestTransportScreen({super.key});

  @override
  State<RequestTransportScreen> createState() => _RequestTransportScreenState();
}

class _RequestTransportScreenState extends State<RequestTransportScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fromController =
      TextEditingController(); // ✅ FIX (ex zone)
  final TextEditingController toController =
      TextEditingController(); // ✅ FIX aggiunto
  final TextEditingController detailsController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController seatsController =
      TextEditingController(); // ✅ FIX aggiunto

  bool loading = false;
  DateTime? selectedDate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      await supabase.from('ads').insert({
        'user_id': user.id,
        'service_type': 'Trasporti',
        'from_location': fromController.text, // ✅ FIX
        'to_location': toController.text, // ✅ FIX
        'description': detailsController.text,
        'capacity': seatsController.text, // ✅ FIX posti richiesti
        'price': 0, // mantenuto ma NON usato
        'transport_date': selectedDate!.toIso8601String(), // ✅ FIX
        'ad_type': 'request',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('ERRORE INSERT: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel salvataggio')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Richiedi trasporto',
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
                decoration:
                    const InputDecoration(labelText: 'Partenza'), // ✅ FIX
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: toController,
                decoration:
                    const InputDecoration(labelText: 'Destinazione'), // ✅ FIX
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: seatsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Posti richiesti'), // ✅ FIX
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: detailsController,
                decoration: const InputDecoration(labelText: 'Dettagli'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Data',
                  hintText: 'Seleziona data',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD84D),
                  foregroundColor: Colors.black,
                ),
                onPressed: loading ? null : _submitRequest,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Invia richiesta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
