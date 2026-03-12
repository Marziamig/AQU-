import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatStore {
  ChatStore._privateConstructor() {
    _loadFromPrefs();
  }
  static final ChatStore instance = ChatStore._privateConstructor();

  final Map<String, List<Map<String, dynamic>>> _conversations = {};
  final String _prefsKey = 'chat_messages';

  final _readyCompleter = Completer<void>();

  /// Await this future to ensure persisted messages are loaded.
  Future<void> get ready => _readyCompleter.future;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _readyCompleter.complete();
        return;
      }

      final List<dynamic> data = json.decode(raw);

      for (final item in data) {
        final map = Map<String, dynamic>.from(item as Map);

        final cid = map['conversationId'] as String? ?? 'conversation_1';

        // 🔒 sicurezza: ignora messaggi marcati come eliminati
        if (map['is_deleted'] == true) continue;

        _conversations.putIfAbsent(cid, () => []);

        _conversations[cid]!.add({
          'text': map['text'],
          'sender': map['sender'],
          'timestamp': map['timestamp'],
          'is_deleted': map['is_deleted'] ?? false,
        });
      }
    } catch (_) {
      // ignore errors
    }
    _readyCompleter.complete();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> all = [];

      _conversations.forEach((cid, list) {
        for (final m in list) {
          if (m['is_deleted'] == true) continue;

          all.add({
            'conversationId': cid,
            'text': m['text'],
            'sender': m['sender'],
            'timestamp': m['timestamp'],
            'is_deleted': m['is_deleted'] ?? false,
          });
        }
      });

      await prefs.setString(_prefsKey, json.encode(all));
    } catch (_) {
      // ignore write errors
    }
  }

  List<Map<String, dynamic>> getMessages(String conversationId) {
    final list = _conversations[conversationId] ?? [];

    // 🔒 non restituire messaggi eliminati
    return list.where((m) => m['is_deleted'] != true).toList();
  }

  void sendMessage(String conversationId, String text, {String sender = 'me'}) {
    final msg = {
      'text': text,
      'sender': sender,
      'timestamp': DateTime.now().toIso8601String(),
      'is_deleted': false,
    };

    _conversations.putIfAbsent(conversationId, () => []);
    _conversations[conversationId]!.add(msg);

    // persist asynchronously
    unawaited(_saveToPrefs());
  }

  void deleteMessage(String conversationId, int index) {
    if (!_conversations.containsKey(conversationId)) return;
    if (index < 0 || index >= _conversations[conversationId]!.length) return;

    _conversations[conversationId]![index]['is_deleted'] = true;

    unawaited(_saveToPrefs());
  }

  void clearConversation(String conversationId) {
    _conversations.remove(conversationId);
    unawaited(_saveToPrefs());
  }
}

// Helper to call an async without awaiting and avoid analyzer hint
void unawaited(Future<void> f) {}
