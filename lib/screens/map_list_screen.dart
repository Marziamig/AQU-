import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

class MapListScreen extends StatefulWidget {
  const MapListScreen({super.key});

  @override
  State<MapListScreen> createState() => _MapListScreenState();
}

class _MapListScreenState extends State<MapListScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];

  LatLng? _center;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'Trasporti':
        return Icons.directions_car;
      case 'Trasporto':
        return Icons.route;
      case 'Servizio':
        return Icons.help_outline;
      default:
        return Icons.work;
    }
  }

  Color _getColor(String? type) {
    switch (type) {
      case 'Trasporti':
        return Colors.blue;
      case 'Trasporto':
        return Colors.green;
      case 'Servizio':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }

  Widget _buildStars(double rating) {
    final fullStars = rating.floor();
    return Row(
      children: List.generate(
        fullStars,
        (index) => const Icon(Icons.star, color: Colors.orange, size: 14),
      ),
    );
  }

  Widget _emptyMapState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.map_outlined, size: 90, color: Colors.grey),
          SizedBox(height: 14),
          Text(
            'Nessun annuncio vicino a te',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Appena qualcuno pubblica, lo vedrai qui sulla mappa.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _loadAds() async {
    try {
      final permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final myId = supabase.auth.currentUser?.id;

      _center = LatLng(pos.latitude, pos.longitude);

      final data = await supabase
          .from('ads')
          .select('*, profiles(rating_avg, rating_count)');

      final List<Marker> loaded = [];

      for (final ad in data) {
        if (myId != null && ad['user_id'] == myId) continue;
        if (ad['lat'] == null || ad['lng'] == null) continue;

        loaded.add(
          Marker(
            point: LatLng(
              (ad['lat'] as num).toDouble(),
              (ad['lng'] as num).toDouble(),
            ),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _openAdSheet(ad),
              child: Icon(
                _getIcon(ad['service_type']),
                color: _getColor(ad['service_type']),
                size: 34,
              ),
            ),
          ),
        );
      }

      setState(() {
        _markers
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });

      _mapController.move(_center!, 14);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _openAdSheet(Map<String, dynamic> ad) {
    final receiverId = ad['user_id'];

    final profile = ad['profiles'];
    final rating = (profile?['rating_avg'] ?? 0).toDouble();
    final ratingCount = profile?['rating_count'] ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ad['user_name'] ?? 'Utente',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (ratingCount > 0)
                    Row(
                      children: [
                        _buildStars(rating),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (ad['service_type'] != null) Text(ad['service_type']),
              const SizedBox(height: 8),
              if (ad['from_location'] != null && ad['to_location'] != null)
                Text('${ad['from_location']} → ${ad['to_location']}'),
              const SizedBox(height: 8),
              Text('€ ${ad['price']}'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD84D),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'conversationId': ad['id'].toString(),
                      'receiverId': receiverId,
                    },
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('Contatta'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _center == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annunci sulla mappa',
            style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _markers.isEmpty
          ? _emptyMapState()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center!,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black12,
                        )
                      ],
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        _legendItem(Icons.directions_car, Colors.blue,
                            'Offro trasporto'),
                        _legendItem(
                            Icons.route, Colors.green, 'Cerco trasporto'),
                        _legendItem(
                            Icons.help_outline, Colors.amber, 'Cerco servizio'),
                        _legendItem(
                            Icons.work, Colors.orange, 'Offro servizio'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
