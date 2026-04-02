# ADR-003: Foto utente processate in memoria e mai salvate

## Stato
Accettata

## Contesto
Le feature AI richiedono l'upload di foto (macchinari e foto corporee). Le foto corporee sono dati biometrici sensibili. Salvare foto su disco o cloud storage crea rischi di privacy, compliance GDPR, e responsabilita legale in caso di breach.

## Decisione
Le foto vengono processate esclusivamente in memoria:
1. Client invia foto come multipart/form-data
2. Server riceve in buffer RAM (non salva su disco)
3. Server invia a Claude API per analisi
4. Server salva SOLO il risultato testuale (esercizi, scheda)
5. Server salva hash SHA256 della foto per caching/dedup
6. Buffer foto viene deallocato (garbage collected)

## Conseguenze
- PRO: zero rischio di leak foto in caso di breach database/storage
- PRO: compliance GDPR semplificata (non conserviamo dati biometrici)
- PRO: meno storage necessario
- CON: non possiamo ri-analizzare una foto senza che l'utente la carichi di nuovo
- CON: il caching funziona solo se l'utente invia la stessa identica foto (stesso hash)
- MITIGAZIONE: l'utente puo sempre ri-scattare la foto

## Alternative considerate
1. Salvare foto encrypted su S3: scartato per rischio residuo e complessita
2. Salvare foto per N giorni poi eliminare: scartato perche aggiunge complessita di cleanup
