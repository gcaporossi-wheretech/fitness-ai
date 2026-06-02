import 'package:flutter/material.dart';

import 'package:fitness_ai/core/storage/hive_storage.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';

const String kDisclaimerText =
    'FitnessAI fornisce schede di allenamento e statistiche a scopo '
    'informativo e di auto-monitoraggio. NON è un servizio medico e non '
    'sostituisce il parere di un medico o di un professionista qualificato.\n\n'
    'Consulta un medico prima di iniziare un programma di allenamento, '
    'soprattutto in caso di patologie, infortuni o dubbi sul tuo stato di '
    'salute. Interrompi l\'attività e rivolgiti a un medico se avverti dolore '
    'o malessere.\n\n'
    'Svolgendo gli esercizi ti assumi la responsabilità della corretta '
    'esecuzione. Le eventuali foto caricate servono solo a generare i tuoi '
    'contenuti e puoi chiederne la cancellazione in qualsiasi momento '
    '(Profilo → Esci / contatta l\'amministratore).';

const _acceptedKey = 'disclaimer_accepted';

bool disclaimerAccepted() => HiveStorage.user.get(_acceptedKey) == true;

/// Show the disclaimer. When [gate] is true it requires explicit acceptance
/// (used once on first access); otherwise it is just an informational view.
Future<void> showDisclaimerDialog(BuildContext context, {bool gate = false}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !gate,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgSecondary,
      title: const Text('Disclaimer & Privacy'),
      content: const SingleChildScrollView(child: Text(kDisclaimerText)),
      actions: [
        if (gate)
          TextButton(
            onPressed: () {
              HiveStorage.user.put(_acceptedKey, true);
              Navigator.pop(ctx);
            },
            child: const Text('Ho capito e accetto'),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
      ],
    ),
  );
}
