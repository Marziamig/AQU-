import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  bool loading = true;
  List ads = [];
  Position? userPosition;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    try {
      final permission = await Geolocator.requestPermission();

      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      final myId = supabase.auth.currentUser?.id;

      final response = await supabase
          .from('ads')
          .select(
              '*, profiles(rating_avg, rating_count, avg_response_minutes, response_speed_label)')
          .eq('status', 'open');

      final filtered = myId == null
          ? List.from(response)
          : response.where((ad) => ad['user_id'] != myId).toList();

      final now = DateTime.now();

      for (var ad in filtered) {
        if (ad['lat'] != null && ad['lng'] != null && userPosition != null) {
          final distance = Geolocator.distanceBetween(
            userPosition!.latitude,
            userPosition!.longitude,
            (ad['lat'] as num).toDouble(),
            (ad['lng'] as num).toDouble(),
          );
          ad['distance'] = distance;
        } else {
          ad['distance'] = double.infinity;
        }
      }

      filtered.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? now;
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? now;

        final aIsNew = now.difference(aDate).inDays <= 30;
        final bIsNew = now.difference(bDate).inDays <= 30;

        if (aIsNew && !bIsNew) return -1;
        if (!aIsNew && bIsNew) return 1;

        final aDistance = a['distance'] ?? double.infinity;
        final bDistance = b['distance'] ?? double.infinity;

        if (aDistance != bDistance) {
          return aDistance.compareTo(bDistance);
        }

        final aRating = (a['profiles']?['rating_avg'] ?? 0).toDouble();
        final bRating = (b['profiles']?['rating_avg'] ?? 0).toDouble();

        if (aRating != bRating) {
          return bRating.compareTo(aRating);
        }

        return bDate.compareTo(aDate);
      });

      setState(() {
        ads = filtered;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel caricamento annunci')),
      );
    }
  }

  Future<void> _markMessagesAsRead(String adId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('ad_id', adId)
        .neq('sender_id', user.id);
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

  Widget _buildResponseBadge(String? label) {
    if (label == 'fast') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '🟢 Risponde velocemente',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (label == 'same_day') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '🟡 Risponde in giornata',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _emptyState() {
    return const Center(
      child: Text('Nessun annuncio disponibile'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annunci', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ads.isEmpty
              ? _emptyState()
              : ListView.builder(
                  itemCount: ads.length,
                  itemBuilder: (context, i) {
                    final ad = ads[i];
                    final receiverId = ad['user_id'];

                    final profile = ad['profiles'];
                    final rating = (profile?['rating_avg'] ?? 0).toDouble();
                    final ratingCount = profile?['rating_count'] ?? 0;
                    final responseLabel = profile?['response_speed_label'];

                    final createdAt =
                        DateTime.tryParse(ad['created_at'] ?? '') ??
                            DateTime.now();
                    final isNew =
                        DateTime.now().difference(createdAt).inDays <= 30;

                    final distanceMeters = ad['distance'];
                    String distanceText = '';

                    if (distanceMeters != null &&
                        distanceMeters != double.infinity) {
                      if (distanceMeters < 1000) {
                        distanceText = '${distanceMeters.toStringAsFixed(0)} m';
                      } else {
                        distanceText =
                            '${(distanceMeters / 1000).toStringAsFixed(1)} km';
                      }
                    }

                    final adType = ad['ad_type'] ?? 'request';
                    final isRequest = adType == 'request';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isRequest
                              ? Colors.orange.shade300
                              : Colors.blue.shade300,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isRequest ? Icons.help_outline : Icons.campaign,
                          color: isRequest ? Colors.orange : Colors.blue,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(ad['user_name'] ?? 'Utente'),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isRequest
                                        ? Colors.orange.shade100
                                        : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isRequest ? 'Richiesta' : 'Offerta',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (isNew) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Nuovo',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            _buildResponseBadge(responseLabel),
                            if (ratingCount > 0)
                              Row(
                                children: [
                                  const SizedBox(width: 6),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ad['service_type'] != null)
                              Text(ad['service_type']),
                            const SizedBox(height: 4),
                            if (ad['description'] != null &&
                                ad['description'].toString().isNotEmpty)
                              Text(
                                ad['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              '€ ${ad['price']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (distanceText.isNotEmpty)
                              Text(
                                distanceText,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chat),
                        onTap: () async {
                          await _markMessagesAsRead(ad['id'].toString());

                          Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: {
                              'conversationId': ad['id'].toString(),
                              'receiverId': receiverId,
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFD84D),
        onPressed: () => Navigator.pushNamed(context, '/create-ad'),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
