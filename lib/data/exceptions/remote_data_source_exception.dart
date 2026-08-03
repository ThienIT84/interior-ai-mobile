class RemoteDataSourceException implements Exception {
  const RemoteDataSourceException({
    required this.message,
    required this.code,
    this.statusCode,
  });

  final String message;
  final String code;
  final int? statusCode;

  bool get isRedisUnavailable =>
      statusCode == 503 && code == 'redis_unavailable';

  @override
  String toString() => message;
}
