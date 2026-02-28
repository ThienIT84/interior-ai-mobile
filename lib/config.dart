// Configuration cho backend API
class AppConfig {
  // Môi trường development
  static const bool isDevelopment = true;

  // === BACKEND URL ===
  // Luôn dùng localhost với ADB reverse (cả USB và wireless)
  // Setup: adb reverse tcp:8000 tcp:8000
  static const String _backendUrl = "http://localhost:8000";

  static String get baseUrl => _backendUrl;

  static String get predictEndpoint => "$baseUrl/predict";

  // Timeout configuration (increased for SAM processing)
  static const Duration uploadTimeout = Duration(seconds: 120);
  static const Duration receiveTimeout = Duration(seconds: 120);
}
