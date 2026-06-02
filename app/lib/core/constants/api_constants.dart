/// API endpoint constants.
/// In development, the backend runs on localhost via Docker Compose.
/// In production, all calls go through the Traefik API gateway.
class ApiConstants {
  ApiConstants._();

  /// Base URL for the API. Override via environment or config.
  /// Android emulator uses 10.0.2.2 for host localhost.
  /// iOS simulator uses localhost directly.
  static const String devBaseUrl = 'http://10.0.2.2';
  static const String prodBaseUrl = 'https://fitness-ai.caporossi.net';

  // Auth endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authMe = '/auth/me';
  static const String authMeExport = '/auth/me/export';
  static const String authCredits = '/auth/credits';
  static const String authWebauthnRegisterBegin = '/auth/webauthn/register/begin';
  static const String authWebauthnRegisterComplete = '/auth/webauthn/register/complete';
  static const String authWebauthnLogin = '/auth/webauthn/login';

  // Workout endpoints
  static const String workoutPlans = '/workouts/plans';
  static const String workoutSessions = '/workouts/sessions';
  static const String workoutSync = '/workouts/sync';
  static const String workoutExercises = '/workouts/exercises';

  // AI endpoints
  static const String aiVisionScan = '/ai/vision/scan';
  static const String aiVisionResult = '/ai/vision/result';
  static const String aiCoachGenerate = '/ai/coach/generate';
  static const String aiCoachResult = '/ai/coach/result';

  // Analytics endpoints
  static const String analyticsProgress = '/analytics/progress';
  static const String analyticsVolume = '/analytics/volume';
  static const String analyticsAdherence = '/analytics/adherence';
  static const String analyticsSummary = '/analytics/summary';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
