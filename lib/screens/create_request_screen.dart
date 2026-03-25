import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geocoding/geocoding.dart';

final supabase = Supabase.instance.client;

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final fromController = TextEditingController();
  final toController = TextEditingController();
  final priceController = TextEditingController();
  final capacityController = TextEditingController();
  final descriptionController = TextEditingController();

  LatLng? userPosition;
  bool loading = false;

  String selectedType = 'Trasporto';
  String selectedService = 'Pulizie';

  DateTime? selectedDate; // ✅ FIX

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      userPosition = LatLng(pos.latitude, pos.longitude);
    });
  }

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

  Future<void> _pickDate() async {
    // ✅ FIX
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (userPosition == null) return;

    if (selectedType == 'Trasporto' && selectedDate == null) {
      // ✅ FIX
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una data')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);

    try {
      final userName = await _getUserName();

      String? zone;
      try {
        final placemarks = await placemarkFromCoordinates(
          userPosition!.latitude,
          userPosition!.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          zone = (place.locality ??
                  place.subAdministrativeArea ??
                  place.administrativeArea)
              ?.toLowerCase();
        }
      } catch (_) {
        zone =
            "${userPosition!.latitude.toStringAsFixed(2)},${userPosition!.longitude.toStringAsFixed(2)}";
      }

      zone ??=
          "${userPosition!.latitude.toStringAsFixed(2)},${userPosition!.longitude.toStringAsFixed(2)}";

      final insertResponse = await supabase
          .from('ads')
          .insert({
            'user_id': user.id,
            'user_name': userName,
            'service_type':
                selectedType == 'Servizio' ? selectedService : 'Trasporto',
            'description':
                selectedType == 'Servizio' ? descriptionController.text : null,
            'from_location':
                selectedType == 'Trasporto' ? fromController.text : null,
            'to_location':
                selectedType == 'Trasporto' ? toController.text : null,
            'capacity': selectedType == 'Trasporto'
                ? int.tryParse(capacityController.text)
                : null,
            'price': selectedType == 'Trasporto'
                ? 0 // ✅ FIX rimosso prezzo trasporto
                : double.parse(priceController.text),
            'transport_date': selectedType == 'Trasporto'
                ? selectedDate!.toIso8601String()
                : null, // ✅ FIX
            'lat': userPosition!.latitude,
            'lng': userPosition!.longitude,
            'zone': zone,
            'status': 'open',
            'ad_type': 'request',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final newAdId = insertResponse['id'];

      await supabase.functions.invoke(
        'match_pro',
        body: {'ad_id': newAdId},
      );

      if (!mounted) return;
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      debugPrint('POSTGREST ERROR: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore DB: ${e.message}')),
      );
    } on FunctionException catch (e) {
      debugPrint('FUNCTION ERROR: ${e.details}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore funzione: ${e.details}')),
      );
    } catch (e) {
      debugPrint('GENERAL ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante la pubblicazione')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuova richiesta',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: userPosition == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: userPosition!,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.aqui.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: userPosition!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Trasporto'),
                                  selected: selectedType == 'Trasporto',
                                  onSelected: (_) {
                                    setState(() {
                                      selectedType = 'Trasporto';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('Servizio'),
                                  selected: selectedType == 'Servizio',
                                  onSelected: (_) {
                                    setState(() {
                                      selectedType = 'Servizio';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (selectedType == 'Trasporto') ...[
                            TextFormField(
                              controller: fromController,
                              decoration: const InputDecoration(
                                  labelText: 'Partenza'), // ✅ FIX
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Obbligatorio'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: toController,
                              decoration: const InputDecoration(
                                  labelText: 'Destinazione'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: capacityController,
                              decoration: const InputDecoration(
                                  labelText: 'Posti richiesti'), // ✅ FIX
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              // ✅ FIX data
                              onTap: _pickDate,
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                      labelText: 'Data trasporto'),
                                  controller: TextEditingController(
                                    text: selectedDate == null
                                        ? ''
                                        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                                  ),
                                  validator: (_) => selectedDate == null
                                      ? 'Obbligatorio'
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (selectedType == 'Servizio') ...[
                            DropdownButtonFormField<String>(
                              initialValue: selectedService,
                              items: const [
                                DropdownMenuItem(
                                    value: 'Pulizie', child: Text('Pulizie')),
                                DropdownMenuItem(
                                    value: 'Infermiere',
                                    child: Text('Infermiere')),
                                DropdownMenuItem(
                                    value: 'Babysitting',
                                    child: Text('Babysitting')),
                                DropdownMenuItem(
                                    value: 'Badante', child: Text('Badante')),
                                DropdownMenuItem(
                                    value: 'Parrucchiere',
                                    child: Text('Parrucchiere')),
                                DropdownMenuItem(
                                    value: 'Estetista',
                                    child: Text('Estetista')),
                                DropdownMenuItem(
                                    value: 'Chef',
                                    child: Text('Chef a domicilio')),
                                DropdownMenuItem(
                                    value: 'Altro', child: Text('Altro')),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedService = v!),
                              decoration: const InputDecoration(
                                  labelText: 'Tipo servizio'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: descriptionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Descrizione'),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Inserisci descrizione'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (selectedType == 'Servizio') // ✅ FIX
                            TextFormField(
                              controller: priceController,
                              decoration: const InputDecoration(
                                  labelText: 'Prezzo (€)'),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final price = double.tryParse(v ?? '');
                                if (price == null || price <= 0) {
                                  return 'Inserisci un prezzo valido';
                                }
                                return null;
                              },
                            ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Pubblica richiesta'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
