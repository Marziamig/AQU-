import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/navigation_drawer.dart';
import 'screens/pro_subscription_screen.dart';

final supabase = Supabase.instance.client;

const Color brandYellow = Color(0xFFFFD84D);
const Color brandBlue = Color(0xFF0D2B45);
const Color backgroundSoft = Color(0xFFF6F4EE);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int unreadMessages = 0;
  int unreadNotifications = 0;
  int completedJobs = 0;
  String userName = '';
  bool isPro = false;

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadUnreadMessages();
    _loadUnreadNotifications();
    _loadUserInfo();
    _loadCompletedJobs();
    _listenMessagesRealtime();
    _listenNotificationsRealtime();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase
        .from('profiles')
        .select('full_name, is_pro')
        .eq('id', user.id)
        .single();

    setState(() {
      userName = profile['full_name'] ?? '';
      isPro = profile['is_pro'] ?? false;
    });
  }

  Future<void> _loadCompletedJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('payments')
        .select('id')
        .eq('user_id', user.id)
        .eq('status', 'paid');

    setState(() {
      completedJobs = data.length;
    });
  }

  Future<void> _loadUnreadMessages() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('messages')
        .select('id')
        .eq('receiver_id', user.id)
        .eq('is_read', false);

    setState(() {
      unreadMessages = data.length;
    });
  }

  void _listenMessagesRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _messagesChannel = supabase
        .channel('home-messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMsg = payload.newRecord;

            if (newMsg['receiver_id']?.toString() == user.id &&
                (newMsg['is_read'] == false || newMsg['is_read'] == null)) {
              _loadUnreadMessages();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final updated = payload.newRecord;

            if (updated['receiver_id']?.toString() == user.id) {
              _loadUnreadMessages();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadUnreadNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);

    setState(() {
      unreadNotifications = data.length;
    });
  }

  void _listenNotificationsRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _notificationsChannel = supabase
        .channel('home-notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newNotification = payload.newRecord;

            if (newNotification['user_id']?.toString() == user.id) {
              _loadUnreadNotifications();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final updated = payload.newRecord;

            if (updated['user_id']?.toString() == user.id) {
              _loadUnreadNotifications();
            }
          },
        )
        .subscribe();
  }

  Widget _buildMessagesIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.mail_outline, size: 22),
          onPressed: () async {
            await Navigator.pushNamed(context, '/messages');
            _loadUnreadMessages();
          },
        ),
        if (unreadMessages > 0)
          Positioned(
            right: 6,
            top: 6,
            child: _buildBadge(unreadMessages),
          ),
      ],
    );
  }

  Widget _buildNotificationsIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, size: 22),
          onPressed: () async {
            await Navigator.pushNamed(context, '/notifications');
            _loadUnreadNotifications();
          },
        ),
        if (unreadNotifications > 0)
          Positioned(
            right: 6,
            top: 6,
            child: _buildBadge(unreadNotifications),
          ),
      ],
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 18,
        minHeight: 18,
      ),
      child: Text(
        count > 9 ? '9+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildProBanner() {
    if (isPro) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Diventa PRO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: brandBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ricevi richieste di lavoro prima degli altri grazie al matching automatico.',
            style: TextStyle(color: brandBlue),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProSubscriptionScreen(),
                ),
              );
            },
            child: const Text('Attiva PRO — 6,99€ / mese'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const NavigationDrawerWidget(),
      backgroundColor: backgroundSoft,
      appBar: AppBar(
        title: const Text(
          'Aquì',
          style: TextStyle(
            color: brandBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: brandYellow,
        iconTheme: const IconThemeData(color: brandBlue),
        elevation: 0,
        actions: [
          _buildMessagesIcon(),
          _buildNotificationsIcon(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buongiorno${userName.isNotEmpty ? ', $userName' : ''} 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: brandBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$completedJobs lavori completati',
              style: TextStyle(
                fontSize: 14,
                color: brandBlue.withOpacity(0.6),
              ),
            ),
            _buildProBanner(),
            const SizedBox(height: 28),
            _PrimaryCard(
              icon: Icons.search,
              title: 'Trova un servizio vicino a te',
              subtitle: 'Cerca tra gli annunci disponibili',
              onTap: () => Navigator.pushNamed(context, '/announcements'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Azioni rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: brandBlue,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SecondaryCard(
                  icon: Icons.add_circle_outline,
                  label: 'Offri Servizio',
                  onTap: () => Navigator.pushNamed(context, '/create-ad'),
                ),
                _SecondaryCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'Offri trasporto',
                  onTap: () =>
                      Navigator.pushNamed(context, '/create-transport'),
                ),
                _SecondaryCard(
                  icon: Icons.map_outlined,
                  label: 'Mappa',
                  onTap: () => Navigator.pushNamed(context, '/map-list'),
                ),
                _SecondaryCard(
                  icon: Icons.handshake,
                  label: 'Richiedi servizio / trasporto',
                  onTap: () => Navigator.pushNamed(context, '/create-request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [brandYellow, Color(0xFFFFE88C)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: brandYellow.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: brandBlue),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Trova un servizio vicino a te',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: brandBlue),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Cerca tra gli annunci disponibili',
                    style: TextStyle(fontSize: 14, color: brandBlue),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SecondaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: brandBlue),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: brandBlue),
            ),
          ],
        ),
      ),
    );
  }
}
