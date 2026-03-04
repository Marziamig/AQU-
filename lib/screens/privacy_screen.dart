import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Privacy Policy', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFD84D),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            '''
PRIVACY POLICY - AQUI

Ultimo aggiornamento: 2026

AQUI è una piattaforma marketplace che consente agli utenti di pubblicare annunci, comunicare tramite chat e organizzare servizi o trasporti tra privati.

DATI RACCOLTI
Raccogliamo esclusivamente i dati necessari al funzionamento dell’app:

• Email di registrazione
• Nome visualizzato
• Annunci pubblicati
• Messaggi tra utenti
• Recensioni e valutazioni
• Dati tecnici necessari alla sicurezza della piattaforma

UTILIZZO DEI DATI
I dati vengono utilizzati solo per:

• fornire le funzionalità del marketplace
• gestione delle conversazioni tra utenti
• prevenzione frodi e abusi
• miglioramento della sicurezza del servizio

NON vendiamo né condividiamo i tuoi dati personali con terze parti per finalità pubblicitarie.

PAGAMENTI
I pagamenti effettuati tramite l’app vengono gestiti da provider esterni sicuri. AQUI non memorizza dati completi delle carte di pagamento.

CONSERVAZIONE DATI
I dati restano associati all’account finché l’utente utilizza la piattaforma.

CANCELLAZIONE ACCOUNT
Puoi richiedere la cancellazione del tuo account contattando il supporto tramite la sezione FAQ o i contatti indicati nell’app.

UTILIZZANDO AQUI ACCETTI QUESTA INFORMATIVA SULLA PRIVACY.
''',
            style: TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
  }
}
