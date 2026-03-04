import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List notifications = [];
  bool loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _listenRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    setState(() {
      notifications = data;
      loading = false;
    });

    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id)
        .eq('is_read', false);
  }

  void _listenRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _channel = supabase
        .channel('notifications-page')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newNotification = payload.newRecord;
            if (newNotification['user_id'] == user.id) {
              _loadNotifications();
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Text('Nessuna notifica'),
                )
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];

                    return ListTile(
                      title: Text(
                        n['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(n['body'] ?? ''),
                      trailing: n['is_read'] == false
                          ? const Icon(Icons.circle,
                              size: 10, color: Colors.red)
                          : null,
                      onTap: () async {
                        final user = supabase.auth.currentUser;
                        if (user == null) return;

                        await supabase
                            .from('notifications')
                            .update({'is_read': true}).eq('id', n['id']);
                      },
                    );
                  },
                ),
    );
  }
}
