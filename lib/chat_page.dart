import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';

final supabase = Supabase.instance.client;

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String? receiverId;

  const ChatPage({
    super.key,
    required this.conversationId,
    this.receiverId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List messages = [];
  final Map<String, String> userNames = {};

  RealtimeChannel? _channel;
  RealtimeChannel? _paymentChannel;

  String? adOwnerId;
  double? adPrice;
  String? adServiceType;
  String? adDescription;
  String? adType;

  String paymentStatus = 'none';
  String? paymentRequestId;

  String? payerId;
  String? requesterId;

  double? baseAmount;
  double? percentFee;
  double? fixedFee;
  double? totalAmount;
  bool hasReviewed = false;

  bool isRequestingPayment = false;

  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _loadAdData();
    _loadMessages();
    _loadPaymentStatus();
    _checkIfReviewed();
    _listenRealtime();
    _listenPaymentRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _paymentChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkIfReviewed() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final existing = await supabase
        .from('reviews')
        .select('id')
        .eq('ad_id', widget.conversationId)
        .eq('reviewer_id', user.id)
        .maybeSingle();

    hasReviewed = existing != null;

    if (mounted) setState(() {});
  }

  Future<void> _leaveReview() async {
    final user = supabase.auth.currentUser;
    if (user == null || adOwnerId == null) return;

    int rating = 5;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lascia una recensione'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: rating,
                items: List.generate(
                  5,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1} stelle'),
                  ),
                ),
                onChanged: (value) {
                  rating = value ?? 5;
                },
              ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Commento (facoltativo)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                await supabase.from('reviews').insert({
                  'reviewer_id': user.id,
                  'reviewed_id': adOwnerId,
                  'ad_id': widget.conversationId,
                  'rating': rating,
                  'comment': controller.text.trim(),
                });

                Navigator.pop(context);
              },
              child: const Text('Invia'),
            ),
          ],
        );
      },
    );

    await _checkIfReviewed();
  }

  Future<void> _loadAdData() async {
    final res = await supabase
        .from('ads')
        .select('user_id, price, service_type, description, ad_type')
        .eq('id', widget.conversationId)
        .single();

    adOwnerId = res['user_id'];
    adPrice = (res['price'] as num?)?.toDouble();
    adServiceType = res['service_type'];
    adDescription = res['description'];
    adType = res['ad_type'];

    if (mounted) setState(() {});
  }

  Future<void> _loadPaymentStatus() async {
    final res = await supabase
        .from('payment_requests')
        .select()
        .eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res != null) {
      paymentStatus = res['status'] ?? 'none';
      paymentRequestId = res['id'];
      payerId = res['payer_id'];
      requesterId = res['requester_id'];
      baseAmount = (res['base_amount'] as num?)?.toDouble();
      percentFee = (res['platform_fee_percent'] as num?)?.toDouble();
      fixedFee = (res['platform_fee_fixed'] as num?)?.toDouble();
      totalAmount = (res['total_amount'] as num?)?.toDouble();
    } else {
      paymentStatus = 'none';
      paymentRequestId = null;
      payerId = null;
      requesterId = null;
    }

    if (mounted) setState(() {});
  }

  void _listenPaymentRealtime() {
    _paymentChannel = supabase
        .channel('payment-${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payment_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) async {
            await _loadPaymentStatus();
          },
        )
        .subscribe();
  }

  Future<void> _requestPayment() async {
    if (isRequestingPayment) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null || adPrice == null) return;

    setState(() {
      isRequestingPayment = true;
    });

    String? calculatedPayerId = widget.receiverId;

    if (calculatedPayerId == null) {
      setState(() {
        isRequestingPayment = false;
      });
      return;
    }

    final base = adPrice!;
    final percent = base * 0.05;
    final fixed = 0.50;
    final total = base + percent + fixed;

    baseAmount = base;
    percentFee = percent;
    fixedFee = fixed;
    totalAmount = total;

    await supabase.from('payment_requests').insert({
      'conversation_id': widget.conversationId,
      'ad_id': widget.conversationId,
      'requester_id': myId,
      'payer_id': calculatedPayerId,
      'amount': base,
      'base_amount': base,
      'platform_fee_percent': percent,
      'platform_fee_fixed': fixed,
      'total_amount': total,
      'platform_earning': percent + fixed,
      'status': 'requested',
    });

    await supabase.from('notifications').insert({
      'user_id': calculatedPayerId,
      'title': 'Richiesta di pagamento',
      'body': 'Procedi al pagamento per usufruire del servizio.',
      'is_read': false,
      'reference_id': widget.conversationId,
    });

    await _loadPaymentStatus();
  }

  Future<void> _startPayment() async {
    final myId = supabase.auth.currentUser?.id;
    if (totalAmount == null || paymentRequestId == null || myId != payerId) {
      return;
    }

    try {
      await _paymentService.startPayment(
        totalAmount!,
        requestId: paymentRequestId!,
        requestType: 'service',
      );

      await supabase
          .from('payment_requests')
          .update({'status': 'paid'}).eq('id', paymentRequestId!);

      if (requesterId != null && baseAmount != null) {
        await supabase.from('notifications').insert({
          'user_id': requesterId,
          'title': 'Pagamento effettuato',
          'body':
              'Il pagamento di €${baseAmount!.toStringAsFixed(2)} è stato effettuato.',
          'is_read': false,
          'reference_id': widget.conversationId,
        });
      }

      await _loadPaymentStatus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento completato')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il pagamento')),
      );
    }
  }

  Future<void> _loadMessages() async {
    final data = await supabase
        .from('messages')
        .select()
        .eq('ad_id', widget.conversationId)
        .order('created_at', ascending: true);

    messages
      ..clear()
      ..addAll(data);

    await _loadUserNames();

    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  Future<void> _loadUserNames() async {
    final ids = messages
        .map((m) => m['sender_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    if (ids.isEmpty) return;

    final profiles = await supabase
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', ids);

    for (final p in profiles) {
      userNames[p['id']] = p['full_name'];
    }
  }

  void _listenRealtime() {
    _channel = supabase
        .channel('chat-${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ad_id',
            value: widget.conversationId,
          ),
          callback: (payload) async {
            final newMessage = payload.newRecord;
            messages.add(newMessage);
            await _loadUserNames();
            if (mounted) {
              setState(() {});
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final newMessage = {
      'ad_id': widget.conversationId,
      'sender_id': user.id,
      'receiver_id': widget.receiverId,
      'message': text,
      'is_read': false,
    };

    setState(() {
      messages.add(newMessage);
    });

    await supabase.from('messages').insert(newMessage);
    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;
    final bool isRequest = adType == 'request';

    bool canRequestPayment = false;

    if (adPrice != null && myId != null) {
      if (adType == 'offer' && myId == adOwnerId) {
        canRequestPayment = true;
      }
      if (adType == 'request' && myId != adOwnerId) {
        canRequestPayment = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (adServiceType != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: isRequest ? Colors.orange.shade50 : Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRequest ? 'Richiesta di servizio' : 'Offerta di servizio',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adServiceType!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (adDescription != null && adDescription!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      adDescription!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  if (adPrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '€ ${adPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          if (canRequestPayment &&
              (paymentStatus == 'none' || paymentStatus == 'requested'))
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: (paymentStatus == 'none' && !isRequestingPayment)
                    ? _requestPayment
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (paymentStatus == 'none' && !isRequestingPayment)
                          ? const Color(0xFFFFD84D)
                          : Colors.grey,
                ),
                child: Text(
                  paymentStatus == 'requested'
                      ? 'Richiesta inviata'
                      : 'Richiedi pagamento (€${adPrice!.toStringAsFixed(2)})',
                ),
              ),
            )
          else if (paymentStatus == 'paid' && myId != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Text(
                    'Pagamento effettuato',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!hasReviewed)
                    ElevatedButton(
                      onPressed: _leaveReview,
                      child: const Text('Lascia una recensione'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isMe = msg['sender_id'] == myId;
                final name =
                    isMe ? 'Tu' : userNames[msg['sender_id']] ?? 'Utente';

                return Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFFFFD84D)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['message'] ?? '',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (paymentStatus == 'requested' &&
              myId != null &&
              myId == payerId &&
              totalAmount != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pagamento richiesto',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Servizio: €${(baseAmount ?? 0).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Commissione Aquì: €${((percentFee ?? 0) + (fixedFee ?? 0)).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Totale: €${totalAmount!.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD84D),
                    ),
                    child: const Text(
                      'Procedi al pagamento',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Scrivi un messaggio...',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
