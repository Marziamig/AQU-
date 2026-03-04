import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Termini di utilizzo',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            '''
TERMINI DI UTILIZZO - AQUI

Ultimo aggiornamento: 2026

AQUI è una piattaforma digitale che mette in contatto utenti per la pubblicazione e la fruizione di servizi e trasporti tra privati.

1. RUOLO DELLA PIATTAFORMA
AQUI agisce esclusivamente come intermediario tecnologico.
Non è parte del contratto tra gli utenti e non garantisce l’esecuzione dei servizi.

2. RESPONSABILITÀ DEGLI UTENTI
Ogni utente è responsabile:
• della correttezza delle informazioni pubblicate
• dei servizi offerti o richiesti
• dei pagamenti effettuati
• del rispetto delle leggi vigenti

3. PAGAMENTI E COMMISSIONI
Alcuni servizi possono prevedere una commissione applicata al pagamento.
L’importo viene chiaramente indicato prima della conferma.

4. RECENSIONI
Le recensioni devono essere veritiere e basate su esperienze reali.
AQUI si riserva il diritto di rimuovere contenuti offensivi o fraudolenti.

5. LIMITAZIONE DI RESPONSABILITÀ
AQUI non è responsabile per:
• disservizi tra utenti
• danni diretti o indiretti
• mancata esecuzione di accordi privati

6. SOSPENSIONE ACCOUNT
In caso di violazioni, spam o abuso, l’account può essere sospeso o limitato.

7. LEGGE APPLICABILE
I presenti termini sono regolati dalla normativa vigente.

UTILIZZANDO AQUI ACCETTI INTEGRALMENTE QUESTI TERMINI.
''',
            style: TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
  }
}
