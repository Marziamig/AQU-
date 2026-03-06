import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final supabase = Supabase.instance.client;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;
  List myAds = [];
  final TextEditingController _nameController = TextEditingController();

  double ratingAvg = 0;
  int ratingCount = 0;
  bool isPro = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMyAds();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('profiles')
        .select('full_name, rating_avg, rating_count, is_pro')
        .eq('id', user.id)
        .maybeSingle();

    if (data != null) {
      _nameController.text = data['full_name'] ?? '';
      ratingAvg = (data['rating_avg'] ?? 0).toDouble();
      ratingCount = data['rating_count'] ?? 0;
      isPro = data['is_pro'] ?? false;
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('profiles').upsert({
      'id': user.id,
      'full_name': _nameController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profilo salvato')),
    );
  }

  Future<void> _loadMyAds() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('ads')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      myAds = response;
      loading = false;
    });
  }

  Future<void> _deleteAd(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina annuncio'),
        content: const Text('Sei sicuro di voler eliminare questo annuncio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('ads').delete().eq('id', id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annuncio eliminato')),
      );

      await _loadMyAds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore eliminazione: $e')),
      );
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambia password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Nuova password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.length < 6) return;

              await supabase.auth.updateUser(
                UserAttributes(password: controller.text),
              );

              if (!mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password aggiornata')),
              );
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'Questa operazione è irreversibile. Vuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('profiles')
          .update({'is_deleted': true}).eq('id', user.id);

      await supabase.from('ads').delete().eq('user_id', user.id);

      await supabase.auth.signOut();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore eliminazione: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _manageProSubscription() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('stripe_customer_id')
          .eq('id', user.id)
          .single();

      final customerId = profile['stripe_customer_id'];

      if (customerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer Stripe non trovato')),
        );
        return;
      }

      final response = await supabase.functions.invoke(
        'create-customer-portal',
        body: {'customer_id': customerId},
      );

      final portalUrl = response.data['url'];

      if (portalUrl != null) {
        await launchUrl(Uri.parse(portalUrl));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore apertura portale: $e')),
      );
    }
  }

  Widget _buildStars(double rating) {
    final fullStars = rating.floor();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        fullStars,
        (index) => const Icon(Icons.star, color: Colors.orange, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Icon(Icons.person, size: 80),
                const SizedBox(height: 6),
                if (isPro)
                  const Center(
                    child: Chip(
                      label: Text(
                        'PRO',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.amber,
                    ),
                  ),
                const SizedBox(height: 12),
                if (isPro)
                  ElevatedButton.icon(
                    onPressed: _manageProSubscription,
                    icon: const Icon(Icons.workspace_premium),
                    label: const Text('Gestisci abbonamento PRO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                  ),
                const SizedBox(height: 12),
                if (ratingCount > 0) ...[
                  _buildStars(ratingAvg),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome visualizzato',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD84D),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saveProfile,
                  child: const Text('Salva nome'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'I miei annunci',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (myAds.isEmpty)
                  const Text('Nessun annuncio pubblicato')
                else
                  ...myAds.map((ad) => Card(
                        child: ListTile(
                          title: Text(ad['service_type'] ?? ''),
                          subtitle: ad['from_location'] != null &&
                                  ad['to_location'] != null
                              ? Text(
                                  '${ad['from_location']} → ${ad['to_location']}')
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAd(ad['id'].toString()),
                          ),
                        ),
                      )),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
    );
  }
}
