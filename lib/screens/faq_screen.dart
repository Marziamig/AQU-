import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            _FaqItem(
              question: 'Cos’è Aqui?',
              answer:
                  'Aqui è una piattaforma per trovare e offrire servizi locali in modo semplice e veloce.',
            ),
            _FaqItem(
              question: 'Come pubblico un annuncio?',
              answer:
                  'Vai su “Crea annuncio”, inserisci i dati richiesti e pubblica.',
            ),
            _FaqItem(
              question: 'Come funzionano i trasporti?',
              answer:
                  'Puoi inserire una partenza e una destinazione. Gli utenti vedranno il tuo annuncio sulla mappa.',
            ),
            _FaqItem(
              question: 'Come posso contattare l’assistenza?',
              answer: 'Scrivi a: aquiassistenza@gmail.com',
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
