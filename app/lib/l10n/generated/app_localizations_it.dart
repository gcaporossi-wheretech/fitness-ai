// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class SIt extends S {
  SIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'FitnessAI';

  @override
  String get tagline => 'Il tuo coach AI personale';

  @override
  String get login => 'Accedi';

  @override
  String get register => 'Registrati';

  @override
  String get logout => 'Esci';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Conferma password';

  @override
  String get nameOptional => 'Nome (opzionale)';

  @override
  String get enterEmail => 'Inserisci la tua email';

  @override
  String get invalidEmail => 'Email non valida';

  @override
  String get enterPassword => 'Inserisci la password';

  @override
  String minChars(int count) {
    return 'Minimo $count caratteri';
  }

  @override
  String get mustContainLetter => 'Deve contenere almeno una lettera';

  @override
  String get mustContainNumber => 'Deve contenere almeno un numero';

  @override
  String get passwordsNoMatch => 'Le password non corrispondono';

  @override
  String get noAccountRegister => 'Non hai un account? Registrati';

  @override
  String get haveAccountLogin => 'Hai gia un account? Accedi';

  @override
  String get createAccount => 'Crea Account';

  @override
  String get welcome => 'Benvenuto!';

  @override
  String get createAccountToStart => 'Crea il tuo account per iniziare';

  @override
  String get navWorkout => 'Workout';

  @override
  String get navHistory => 'Storico';

  @override
  String get navStats => 'Grafici';

  @override
  String get navProfile => 'Profilo';

  @override
  String get statistics => 'Statistiche';

  @override
  String get weightProgression => 'Progressione Carico';

  @override
  String get volumeByGroup => 'Volume per Gruppo';

  @override
  String get sessions => 'Sessioni';

  @override
  String get totalVolume => 'Volume totale';

  @override
  String get totalSets => 'Serie totali';

  @override
  String get noProgressData =>
      'Completa qualche serie con pesi\nper vedere la progressione';

  @override
  String get noVolumeData =>
      'Completa qualche allenamento\nper vedere il volume per gruppo';

  @override
  String get coachAI => 'Coach AI';

  @override
  String get bodyPhotos => 'Foto del corpo';

  @override
  String get bodyPhotosInstructions =>
      'Scatta 3 foto per una scheda personalizzata.\nAlmeno una foto e richiesta.';

  @override
  String get front => 'Fronte';

  @override
  String get back => 'Retro';

  @override
  String get side => 'Lato';

  @override
  String get next => 'Avanti';

  @override
  String get skipPhotos => 'Salta le foto';

  @override
  String get personalDataHelp =>
      'Questi dati aiutano il Coach AI a personalizzare la scheda.';

  @override
  String get age => 'Eta';

  @override
  String get goal => 'Obiettivo';

  @override
  String get muscleGain => 'Massa muscolare';

  @override
  String get strength => 'Forza';

  @override
  String get weightLoss => 'Dimagrimento';

  @override
  String get generalFitness => 'Fitness generale';

  @override
  String get experience => 'Esperienza';

  @override
  String get beginner => 'Principiante';

  @override
  String get intermediate => 'Intermedio';

  @override
  String get advanced => 'Avanzato';

  @override
  String get daysPerWeek => 'Giorni a settimana';

  @override
  String get limitations => 'Limitazioni fisiche';

  @override
  String get limitationsHint => 'Es: problemi alle spalle, ginocchia...';

  @override
  String get generatePlan => 'Genera Scheda';

  @override
  String get insufficientCredits => 'Crediti AI insufficienti';

  @override
  String get sendingData => 'Invio dati al Coach AI...';

  @override
  String get generatingPlan => 'Generazione scheda personalizzata...';

  @override
  String get analyzing => 'Analisi in corso...';

  @override
  String get generationFailed => 'Generazione fallita';

  @override
  String get errorDuring => 'Errore durante la generazione';

  @override
  String get visionScan => 'Scansione AI';

  @override
  String get scanEquipment => 'Scansiona Macchinario';

  @override
  String get pointCamera => 'Inquadra il macchinario con la fotocamera';

  @override
  String get scanPhoto => 'Scatta Foto';

  @override
  String get processing => 'Elaborazione...';

  @override
  String get equipmentRecognized => 'Macchinario riconosciuto';

  @override
  String get suggestedExercises => 'Esercizi suggeriti';

  @override
  String get scanAgain => 'Scansiona un altro';

  @override
  String creditsCost(int count) {
    return 'Costa $count credito';
  }

  @override
  String get profile => 'Profilo';

  @override
  String get aiCredits => 'Crediti AI';

  @override
  String get buyCredits => 'Acquista crediti';

  @override
  String get language => 'Lingua';

  @override
  String get italian => 'Italiano';

  @override
  String get english => 'English';

  @override
  String get save => 'Salva';

  @override
  String get saving => 'Salvataggio...';

  @override
  String get savedSuccess => 'Salvato con successo';

  @override
  String memberSince(String date) {
    return 'Membro dal $date';
  }

  @override
  String get exercises => 'Esercizi';

  @override
  String get sets => 'Serie';

  @override
  String get reps => 'Ripetizioni';

  @override
  String get weight => 'Peso';

  @override
  String get rest => 'Recupero';

  @override
  String get notes => 'Note';

  @override
  String get startWorkout => 'Inizia Allenamento';

  @override
  String get endWorkout => 'Termina Allenamento';

  @override
  String get addExercise => 'Aggiungi Esercizio';

  @override
  String get addSet => 'Aggiungi Serie';

  @override
  String get workoutCompleted => 'Allenamento Completato!';

  @override
  String get duration => 'Durata';

  @override
  String get noWorkoutsYet => 'Nessun allenamento registrato';

  @override
  String get calendar => 'Calendario';

  @override
  String get today => 'Oggi';

  @override
  String get scheduledWorkout => 'Allenamento pianificato';

  @override
  String get noScheduled => 'Nessun allenamento pianificato';

  @override
  String get offline => 'Offline';

  @override
  String get syncing => 'Sincronizzazione...';

  @override
  String get synced => 'Sincronizzato';

  @override
  String get syncFailed => 'Sincronizzazione fallita';

  @override
  String pendingSync(int count) {
    return '$count in attesa di sincronizzazione';
  }

  @override
  String get errorGeneric => 'Si e verificato un errore';

  @override
  String get retry => 'Riprova';

  @override
  String get cancel => 'Annulla';

  @override
  String get confirm => 'Conferma';

  @override
  String get delete => 'Elimina';

  @override
  String get edit => 'Modifica';

  @override
  String get close => 'Chiudi';

  @override
  String get loading => 'Caricamento...';

  @override
  String get noData => 'Nessun dato disponibile';
}
