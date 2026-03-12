import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List chats = [];
  bool loading = true;
  final Map<String, String> userNames = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await supabase
          .from('messages')
          .select()
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .order('created_at', ascending: false);

      final visible = data.where((msg) {
        if (msg['sender_id'] == user.id) {
          return msg['deleted_by_sender'] != true;
        } else {
          return msg['deleted_by_receiver'] != true;
        }
      }).toList();

      final Map<String, Map<String, dynamic>> uniqueChats = {};

      for (final msg in visible) {
        final adId = msg['ad_id'];
        if (!uniqueChats.containsKey(adId)) {
          uniqueChats[adId] = msg;
        }
      }

      chats = uniqueChats.values.toList();

      await _loadUserNames();

      setState(() {
        loading = false;
      });
    } catch (e) {
      debugPrint('MESSAGES LOAD ERROR: $e');
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadUserNames() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final ids = <String>{};

    for (final chat in chats) {
      final otherUser = chat['sender_id'] == user.id
          ? chat['receiver_id']
          : chat['sender_id'];

      if (otherUser != null) {
        ids.add(otherUser);
      }
    }

    if (ids.isEmpty) return;

    try {
      final profiles = await supabase
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids.toList())
          .eq('is_deleted', false);

      for (final p in profiles) {
        userNames[p['id']] = p['full_name'] ?? 'Utente';
      }
    } catch (e) {
      debugPrint('PROFILE LOAD ERROR: $e');
    }
  }

  Future<void> _markChatAsRead(String adId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('ad_id', adId)
          .eq('receiver_id', user.id);
    } catch (_) {}
  }

  Future<void> _deleteConversation(String adId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina conversazione'),
        content: const Text('La conversazione verrà rimossa solo per te.'),
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
      final messages = await supabase
          .from('messages')
          .select('id, sender_id, receiver_id')
          .eq('ad_id', adId);

      for (final msg in messages) {
        if (msg['sender_id'] == user.id) {
          await supabase
              .from('messages')
              .update({'deleted_by_sender': true}).eq('id', msg['id']);
        }

        if (msg['receiver_id'] == user.id) {
          await supabase
              .from('messages')
              .update({'deleted_by_receiver': true}).eq('id', msg['id']);
        }
      }

      setState(() {
        chats.removeWhere((chat) => chat['ad_id'] == adId);
      });
    } catch (e) {
      debugPrint('DELETE CHAT ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaggi', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
              ? const Center(child: Text('Nessuna conversazione'))
              : ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final chat = chats[i];

                    final otherUserId = chat['sender_id'] == myId
                        ? chat['receiver_id']
                        : chat['sender_id'];

                    final name = userNames[otherUserId] ?? 'Utente';

                    final bool unread = chat['receiver_id'] == myId &&
                        (chat['is_read'] == false || chat['is_read'] == null);

                    return Dismissible(
                      key: Key(chat['ad_id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _deleteConversation(chat['ad_id']);
                        return false;
                      },
                      child: Container(
                        color: unread
                            ? Colors.grey.withOpacity(0.15)
                            : Colors.transparent,
                        child: ListTile(
                          leading: const Icon(Icons.chat),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            chat['message'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            await _markChatAsRead(chat['ad_id']);

                            Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: {
                                'conversationId': chat['ad_id'],
                                'receiverId': otherUserId,
                              },
                            );

                            _loadChats();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
