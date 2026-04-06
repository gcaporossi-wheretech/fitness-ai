// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FitnessAI';

  @override
  String get tagline => 'Your personal AI coach';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Sign up';

  @override
  String get logout => 'Log out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String minChars(int count) {
    return 'Minimum $count characters';
  }

  @override
  String get mustContainLetter => 'Must contain at least one letter';

  @override
  String get mustContainNumber => 'Must contain at least one number';

  @override
  String get passwordsNoMatch => 'Passwords do not match';

  @override
  String get noAccountRegister => 'Don\'t have an account? Sign up';

  @override
  String get haveAccountLogin => 'Already have an account? Log in';

  @override
  String get createAccount => 'Create Account';

  @override
  String get welcome => 'Welcome!';

  @override
  String get createAccountToStart => 'Create your account to get started';

  @override
  String get navWorkout => 'Workout';

  @override
  String get navHistory => 'History';

  @override
  String get navStats => 'Stats';

  @override
  String get navProfile => 'Profile';

  @override
  String get statistics => 'Statistics';

  @override
  String get weightProgression => 'Weight Progression';

  @override
  String get volumeByGroup => 'Volume by Group';

  @override
  String get sessions => 'Sessions';

  @override
  String get totalVolume => 'Total volume';

  @override
  String get totalSets => 'Total sets';

  @override
  String get noProgressData =>
      'Complete some weighted sets\nto see your progression';

  @override
  String get noVolumeData =>
      'Complete some workouts\nto see volume by muscle group';

  @override
  String get coachAI => 'AI Coach';

  @override
  String get bodyPhotos => 'Body photos';

  @override
  String get bodyPhotosInstructions =>
      'Take 3 photos for a personalized plan.\nAt least one photo is required.';

  @override
  String get front => 'Front';

  @override
  String get back => 'Back';

  @override
  String get side => 'Side';

  @override
  String get next => 'Next';

  @override
  String get skipPhotos => 'Skip photos';

  @override
  String get personalDataHelp =>
      'This data helps the AI Coach personalize your plan.';

  @override
  String get age => 'Age';

  @override
  String get goal => 'Goal';

  @override
  String get muscleGain => 'Muscle gain';

  @override
  String get strength => 'Strength';

  @override
  String get weightLoss => 'Weight loss';

  @override
  String get generalFitness => 'General fitness';

  @override
  String get experience => 'Experience';

  @override
  String get beginner => 'Beginner';

  @override
  String get intermediate => 'Intermediate';

  @override
  String get advanced => 'Advanced';

  @override
  String get daysPerWeek => 'Days per week';

  @override
  String get limitations => 'Physical limitations';

  @override
  String get limitationsHint => 'E.g.: shoulder issues, knee problems...';

  @override
  String get generatePlan => 'Generate Plan';

  @override
  String get insufficientCredits => 'Insufficient AI credits';

  @override
  String get sendingData => 'Sending data to AI Coach...';

  @override
  String get generatingPlan => 'Generating personalized plan...';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get generationFailed => 'Generation failed';

  @override
  String get errorDuring => 'Error during generation';

  @override
  String get visionScan => 'AI Scan';

  @override
  String get scanEquipment => 'Scan Equipment';

  @override
  String get pointCamera => 'Point the camera at the equipment';

  @override
  String get scanPhoto => 'Take Photo';

  @override
  String get processing => 'Processing...';

  @override
  String get equipmentRecognized => 'Equipment recognized';

  @override
  String get suggestedExercises => 'Suggested exercises';

  @override
  String get scanAgain => 'Scan another';

  @override
  String creditsCost(int count) {
    return 'Costs $count credit';
  }

  @override
  String get profile => 'Profile';

  @override
  String get aiCredits => 'AI Credits';

  @override
  String get buyCredits => 'Buy credits';

  @override
  String get language => 'Language';

  @override
  String get italian => 'Italiano';

  @override
  String get english => 'English';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving...';

  @override
  String get savedSuccess => 'Saved successfully';

  @override
  String memberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get exercises => 'Exercises';

  @override
  String get sets => 'Sets';

  @override
  String get reps => 'Reps';

  @override
  String get weight => 'Weight';

  @override
  String get rest => 'Rest';

  @override
  String get notes => 'Notes';

  @override
  String get startWorkout => 'Start Workout';

  @override
  String get endWorkout => 'End Workout';

  @override
  String get addExercise => 'Add Exercise';

  @override
  String get addSet => 'Add Set';

  @override
  String get workoutCompleted => 'Workout Completed!';

  @override
  String get duration => 'Duration';

  @override
  String get noWorkoutsYet => 'No workouts recorded';

  @override
  String get calendar => 'Calendar';

  @override
  String get today => 'Today';

  @override
  String get scheduledWorkout => 'Scheduled workout';

  @override
  String get noScheduled => 'No scheduled workouts';

  @override
  String get offline => 'Offline';

  @override
  String get syncing => 'Syncing...';

  @override
  String get synced => 'Synced';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String pendingSync(int count) {
    return '$count pending sync';
  }

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get loading => 'Loading...';

  @override
  String get noData => 'No data available';
}
