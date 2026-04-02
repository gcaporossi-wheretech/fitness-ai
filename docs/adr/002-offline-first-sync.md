# ADR-002: Offline-First con Last-Write-Wins Sync

## Stato
Accettata

## Contesto
L'app mobile deve funzionare al 100% senza rete (in palestra spesso la connessione e instabile). I dati inseriti offline devono sincronizzarsi quando la connessione torna disponibile, gestendo eventuali conflitti.

## Decisione
Strategia offline-first con last-write-wins:
- Hive (local storage) come storage primario nel client Flutter
- Ogni entita ha un `client_id` UUID generato dal client e un `updated_at` timestamp
- Sync batch: il client invia tutte le sessioni non sincronizzate in un unico POST
- Conflitto: se `client_id` esiste gia sul server, vince la versione con `updated_at` piu recente
- Il server risponde con lo stato di ogni sessione (created/updated/conflict)

## Conseguenze
- PRO: app completamente funzionale offline
- PRO: logica di sync semplice da implementare e testare
- PRO: un solo endpoint di sync per il batch
- CON: in caso di conflitto, la versione piu vecchia viene persa
- MITIGAZIONE: per un singolo utente su un singolo device, i conflitti sono rari
- MITIGAZIONE: i dati di allenamento sono append-only (nuove sessioni), non edit di dati esistenti

## Alternative considerate
1. CRDT: troppo complesso per il tipo di dati (sessioni di allenamento)
2. Operational Transform: overkill, non c'e editing collaborativo
3. Manual conflict resolution: cattiva UX, l'utente non vuole risolvere conflitti
