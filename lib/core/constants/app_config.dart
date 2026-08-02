class AppConfig {
  static const bool isDevelopment = true;
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static String get baseUrl =>
      _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  static String resolveUrl(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.isEmpty) {
      throw const FormatException('Result URL is empty.');
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return uri.toString();
    return '$baseUrl/${value.replaceFirst(RegExp(r'^/+'), '')}';
  }

  // Timeouts
  static const Duration uploadTimeout = Duration(seconds: 120);
  static const Duration receiveTimeout = Duration(seconds: 120);
  static const Duration jobStatusTimeout = Duration(seconds: 10);
  static const Duration longRunningTimeout = Duration(minutes: 30);
}
