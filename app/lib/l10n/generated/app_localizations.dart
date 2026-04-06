import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In it, this message translates to:
  /// **'FitnessAI'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In it, this message translates to:
  /// **'Il tuo coach AI personale'**
  String get tagline;

  /// No description provided for @login.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get login;

  /// No description provided for @register.
  ///
  /// In it, this message translates to:
  /// **'Registrati'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In it, this message translates to:
  /// **'Conferma password'**
  String get confirmPassword;

  /// No description provided for @nameOptional.
  ///
  /// In it, this message translates to:
  /// **'Nome (opzionale)'**
  String get nameOptional;

  /// No description provided for @enterEmail.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la tua email'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In it, this message translates to:
  /// **'Email non valida'**
  String get invalidEmail;

  /// No description provided for @enterPassword.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password'**
  String get enterPassword;

  /// No description provided for @minChars.
  ///
  /// In it, this message translates to:
  /// **'Minimo {count} caratteri'**
  String minChars(int count);

  /// No description provided for @mustContainLetter.
  ///
  /// In it, this message translates to:
  /// **'Deve contenere almeno una lettera'**
  String get mustContainLetter;

  /// No description provided for @mustContainNumber.
  ///
  /// In it, this message translates to:
  /// **'Deve contenere almeno un numero'**
  String get mustContainNumber;

  /// No description provided for @passwordsNoMatch.
  ///
  /// In it, this message translates to:
  /// **'Le password non corrispondono'**
  String get passwordsNoMatch;

  /// No description provided for @noAccountRegister.
  ///
  /// In it, this message translates to:
  /// **'Non hai un account? Registrati'**
  String get noAccountRegister;

  /// No description provided for @haveAccountLogin.
  ///
  /// In it, this message translates to:
  /// **'Hai gia un account? Accedi'**
  String get haveAccountLogin;

  /// No description provided for @createAccount.
  ///
  /// In it, this message translates to:
  /// **'Crea Account'**
  String get createAccount;

  /// No description provided for @welcome.
  ///
  /// In it, this message translates to:
  /// **'Benvenuto!'**
  String get welcome;

  /// No description provided for @createAccountToStart.
  ///
  /// In it, this message translates to:
  /// **'Crea il tuo account per iniziare'**
  String get createAccountToStart;

  /// No description provided for @navWorkout.
  ///
  /// In it, this message translates to:
  /// **'Workout'**
  String get navWorkout;

  /// No description provided for @navHistory.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get navHistory;

  /// No description provided for @navStats.
  ///
  /// In it, this message translates to:
  /// **'Grafici'**
  String get navStats;

  /// No description provided for @navProfile.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get navProfile;

  /// No description provided for @statistics.
  ///
  /// In it, this message translates to:
  /// **'Statistiche'**
  String get statistics;

  /// No description provided for @weightProgression.
  ///
  /// In it, this message translates to:
  /// **'Progressione Carico'**
  String get weightProgression;

  /// No description provided for @volumeByGroup.
  ///
  /// In it, this message translates to:
  /// **'Volume per Gruppo'**
  String get volumeByGroup;

  /// No description provided for @sessions.
  ///
  /// In it, this message translates to:
  /// **'Sessioni'**
  String get sessions;

  /// No description provided for @totalVolume.
  ///
  /// In it, this message translates to:
  /// **'Volume totale'**
  String get totalVolume;

  /// No description provided for @totalSets.
  ///
  /// In it, this message translates to:
  /// **'Serie totali'**
  String get totalSets;

  /// No description provided for @noProgressData.
  ///
  /// In it, this message translates to:
  /// **'Completa qualche serie con pesi\nper vedere la progressione'**
  String get noProgressData;

  /// No description provided for @noVolumeData.
  ///
  /// In it, this message translates to:
  /// **'Completa qualche allenamento\nper vedere il volume per gruppo'**
  String get noVolumeData;

  /// No description provided for @coachAI.
  ///
  /// In it, this message translates to:
  /// **'Coach AI'**
  String get coachAI;

  /// No description provided for @bodyPhotos.
  ///
  /// In it, this message translates to:
  /// **'Foto del corpo'**
  String get bodyPhotos;

  /// No description provided for @bodyPhotosInstructions.
  ///
  /// In it, this message translates to:
  /// **'Scatta 3 foto per una scheda personalizzata.\nAlmeno una foto e richiesta.'**
  String get bodyPhotosInstructions;

  /// No description provided for @front.
  ///
  /// In it, this message translates to:
  /// **'Fronte'**
  String get front;

  /// No description provided for @back.
  ///
  /// In it, this message translates to:
  /// **'Retro'**
  String get back;

  /// No description provided for @side.
  ///
  /// In it, this message translates to:
  /// **'Lato'**
  String get side;

  /// No description provided for @next.
  ///
  /// In it, this message translates to:
  /// **'Avanti'**
  String get next;

  /// No description provided for @skipPhotos.
  ///
  /// In it, this message translates to:
  /// **'Salta le foto'**
  String get skipPhotos;

  /// No description provided for @personalDataHelp.
  ///
  /// In it, this message translates to:
  /// **'Questi dati aiutano il Coach AI a personalizzare la scheda.'**
  String get personalDataHelp;

  /// No description provided for @age.
  ///
  /// In it, this message translates to:
  /// **'Eta'**
  String get age;

  /// No description provided for @goal.
  ///
  /// In it, this message translates to:
  /// **'Obiettivo'**
  String get goal;

  /// No description provided for @muscleGain.
  ///
  /// In it, this message translates to:
  /// **'Massa muscolare'**
  String get muscleGain;

  /// No description provided for @strength.
  ///
  /// In it, this message translates to:
  /// **'Forza'**
  String get strength;

  /// No description provided for @weightLoss.
  ///
  /// In it, this message translates to:
  /// **'Dimagrimento'**
  String get weightLoss;

  /// No description provided for @generalFitness.
  ///
  /// In it, this message translates to:
  /// **'Fitness generale'**
  String get generalFitness;

  /// No description provided for @experience.
  ///
  /// In it, this message translates to:
  /// **'Esperienza'**
  String get experience;

  /// No description provided for @beginner.
  ///
  /// In it, this message translates to:
  /// **'Principiante'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In it, this message translates to:
  /// **'Intermedio'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In it, this message translates to:
  /// **'Avanzato'**
  String get advanced;

  /// No description provided for @daysPerWeek.
  ///
  /// In it, this message translates to:
  /// **'Giorni a settimana'**
  String get daysPerWeek;

  /// No description provided for @limitations.
  ///
  /// In it, this message translates to:
  /// **'Limitazioni fisiche'**
  String get limitations;

  /// No description provided for @limitationsHint.
  ///
  /// In it, this message translates to:
  /// **'Es: problemi alle spalle, ginocchia...'**
  String get limitationsHint;

  /// No description provided for @generatePlan.
  ///
  /// In it, this message translates to:
  /// **'Genera Scheda'**
  String get generatePlan;

  /// No description provided for @insufficientCredits.
  ///
  /// In it, this message translates to:
  /// **'Crediti AI insufficienti'**
  String get insufficientCredits;

  /// No description provided for @sendingData.
  ///
  /// In it, this message translates to:
  /// **'Invio dati al Coach AI...'**
  String get sendingData;

  /// No description provided for @generatingPlan.
  ///
  /// In it, this message translates to:
  /// **'Generazione scheda personalizzata...'**
  String get generatingPlan;

  /// No description provided for @analyzing.
  ///
  /// In it, this message translates to:
  /// **'Analisi in corso...'**
  String get analyzing;

  /// No description provided for @generationFailed.
  ///
  /// In it, this message translates to:
  /// **'Generazione fallita'**
  String get generationFailed;

  /// No description provided for @errorDuring.
  ///
  /// In it, this message translates to:
  /// **'Errore durante la generazione'**
  String get errorDuring;

  /// No description provided for @visionScan.
  ///
  /// In it, this message translates to:
  /// **'Scansione AI'**
  String get visionScan;

  /// No description provided for @scanEquipment.
  ///
  /// In it, this message translates to:
  /// **'Scansiona Macchinario'**
  String get scanEquipment;

  /// No description provided for @pointCamera.
  ///
  /// In it, this message translates to:
  /// **'Inquadra il macchinario con la fotocamera'**
  String get pointCamera;

  /// No description provided for @scanPhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta Foto'**
  String get scanPhoto;

  /// No description provided for @processing.
  ///
  /// In it, this message translates to:
  /// **'Elaborazione...'**
  String get processing;

  /// No description provided for @equipmentRecognized.
  ///
  /// In it, this message translates to:
  /// **'Macchinario riconosciuto'**
  String get equipmentRecognized;

  /// No description provided for @suggestedExercises.
  ///
  /// In it, this message translates to:
  /// **'Esercizi suggeriti'**
  String get suggestedExercises;

  /// No description provided for @scanAgain.
  ///
  /// In it, this message translates to:
  /// **'Scansiona un altro'**
  String get scanAgain;

  /// No description provided for @creditsCost.
  ///
  /// In it, this message translates to:
  /// **'Costa {count} credito'**
  String creditsCost(int count);

  /// No description provided for @profile.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get profile;

  /// No description provided for @aiCredits.
  ///
  /// In it, this message translates to:
  /// **'Crediti AI'**
  String get aiCredits;

  /// No description provided for @buyCredits.
  ///
  /// In it, this message translates to:
  /// **'Acquista crediti'**
  String get buyCredits;

  /// No description provided for @language.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get language;

  /// No description provided for @italian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get italian;

  /// No description provided for @english.
  ///
  /// In it, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @save.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In it, this message translates to:
  /// **'Salvataggio...'**
  String get saving;

  /// No description provided for @savedSuccess.
  ///
  /// In it, this message translates to:
  /// **'Salvato con successo'**
  String get savedSuccess;

  /// No description provided for @memberSince.
  ///
  /// In it, this message translates to:
  /// **'Membro dal {date}'**
  String memberSince(String date);

  /// No description provided for @exercises.
  ///
  /// In it, this message translates to:
  /// **'Esercizi'**
  String get exercises;

  /// No description provided for @sets.
  ///
  /// In it, this message translates to:
  /// **'Serie'**
  String get sets;

  /// No description provided for @reps.
  ///
  /// In it, this message translates to:
  /// **'Ripetizioni'**
  String get reps;

  /// No description provided for @weight.
  ///
  /// In it, this message translates to:
  /// **'Peso'**
  String get weight;

  /// No description provided for @rest.
  ///
  /// In it, this message translates to:
  /// **'Recupero'**
  String get rest;

  /// No description provided for @notes.
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get notes;

  /// No description provided for @startWorkout.
  ///
  /// In it, this message translates to:
  /// **'Inizia Allenamento'**
  String get startWorkout;

  /// No description provided for @endWorkout.
  ///
  /// In it, this message translates to:
  /// **'Termina Allenamento'**
  String get endWorkout;

  /// No description provided for @addExercise.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi Esercizio'**
  String get addExercise;

  /// No description provided for @addSet.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi Serie'**
  String get addSet;

  /// No description provided for @workoutCompleted.
  ///
  /// In it, this message translates to:
  /// **'Allenamento Completato!'**
  String get workoutCompleted;

  /// No description provided for @duration.
  ///
  /// In it, this message translates to:
  /// **'Durata'**
  String get duration;

  /// No description provided for @noWorkoutsYet.
  ///
  /// In it, this message translates to:
  /// **'Nessun allenamento registrato'**
  String get noWorkoutsYet;

  /// No description provided for @calendar.
  ///
  /// In it, this message translates to:
  /// **'Calendario'**
  String get calendar;

  /// No description provided for @today.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get today;

  /// No description provided for @scheduledWorkout.
  ///
  /// In it, this message translates to:
  /// **'Allenamento pianificato'**
  String get scheduledWorkout;

  /// No description provided for @noScheduled.
  ///
  /// In it, this message translates to:
  /// **'Nessun allenamento pianificato'**
  String get noScheduled;

  /// No description provided for @offline.
  ///
  /// In it, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @syncing.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione...'**
  String get syncing;

  /// No description provided for @synced.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzato'**
  String get synced;

  /// No description provided for @syncFailed.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione fallita'**
  String get syncFailed;

  /// No description provided for @pendingSync.
  ///
  /// In it, this message translates to:
  /// **'{count} in attesa di sincronizzazione'**
  String pendingSync(int count);

  /// No description provided for @errorGeneric.
  ///
  /// In it, this message translates to:
  /// **'Si e verificato un errore'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get close;

  /// No description provided for @loading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In it, this message translates to:
  /// **'Nessun dato disponibile'**
  String get noData;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'it':
      return SIt();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
