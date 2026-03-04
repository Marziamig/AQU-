import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ReviewsScreen extends StatefulWidget {
  final String reviewedUserId;
  final String adId;

  const ReviewsScreen({
    super.key,
    required this.reviewedUserId,
    required this.adId,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  int rating = 0;
  final TextEditingController reviewController = TextEditingController();
  bool loading = false;
  bool alreadyReviewed = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyReviewed();
  }

  Future<void> _checkIfAlreadyReviewed() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('reviews')
        .select('id')
        .eq('ad_id', widget.adId)
        .eq('reviewer_id', user.id);

    if (data.isNotEmpty) {
      alreadyReviewed = true;
      setState(() {});
    }
  }

  Widget _buildStar(int index) {
    return IconButton(
      onPressed: alreadyReviewed
          ? null
          : () {
              setState(() {
                rating = index;
              });
            },
      icon: Icon(
        rating >= index ? Icons.star : Icons.star_border,
        color: Colors.amber,
      ),
    );
  }

  Future<void> _submitReview() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (rating == 0) return;
    if (alreadyReviewed) return;

    setState(() => loading = true);

    await supabase.from('reviews').insert({
      'reviewer_id': user.id,
      'reviewed_id': widget.reviewedUserId,
      'ad_id': widget.adId,
      'rating': rating,
      'comment': reviewController.text,
      'created_at': DateTime.now().toIso8601String(),
    });

    // ⭐ CALCOLO NUOVA MEDIA RECENSIONI
    final allReviews = await supabase
        .from('reviews')
        .select('rating')
        .eq('reviewed_id', widget.reviewedUserId);

    double avg = 0;
    int count = 0;

    if (allReviews.isNotEmpty) {
      count = allReviews.length;
      final sum = allReviews.fold<num>(
        0,
        (prev, r) => prev + (r['rating'] ?? 0),
      );
      avg = sum / count;
    }

    // ⭐ UPDATE PROFILO CON MEDIA STELLE
    await supabase.from('profiles').update({
      'rating_avg': avg,
      'rating_count': count,
    }).eq('id', widget.reviewedUserId);

    alreadyReviewed = true;

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lascia una recensione'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Com’è andata?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStar(1),
                _buildStar(2),
                _buildStar(3),
                _buildStar(4),
                _buildStar(5),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: reviewController,
              maxLines: 4,
              enabled: !alreadyReviewed,
              decoration: const InputDecoration(
                hintText: 'Scrivi una recensione...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading || alreadyReviewed ? null : _submitReview,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Pubblica recensione'),
            )
          ],
        ),
      ),
    );
  }
}
