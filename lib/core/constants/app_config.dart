class AppConfig {
  static const bool isDevelopment = true;
  static const String baseUrl = "http://localhost:8000";

  // Timeouts
  static const Duration uploadTimeout = Duration(seconds: 120);
  static const Duration receiveTimeout = Duration(seconds: 120);
  static const Duration jobStatusTimeout = Duration(seconds: 10);
  static const Duration longRunningTimeout = Duration(minutes: 30);
}
