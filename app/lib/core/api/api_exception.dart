/// Error codes shared with the backend contract.
enum ApiErrorCode {
  unauthorized,
  forbidden,
  validation,
  notFound,
  conflict,
  rateLimited,
  network,
  server,
}

class ApiException implements Exception {
  ApiException(this.code, this.message, {this.field, this.details});

  final ApiErrorCode code;
  final String message;

  /// Present for validation errors so forms can highlight the right field.
  final String? field;
  final Map<String, dynamic>? details;

  /// Friendly message used when the server cannot be reached at all.
  static ApiException network() => ApiException(
        ApiErrorCode.network,
        'No internet connection. Check your connection and try again.',
      );

  bool get isUnauthorized => code == ApiErrorCode.unauthorized;
  bool get isOffline => code == ApiErrorCode.network;

  @override
  String toString() => message;
}

/// Maps a backend error code onto the app's enum.
ApiErrorCode apiErrorCodeFrom(String? value) => switch (value) {
      'UNAUTHORIZED' => ApiErrorCode.unauthorized,
      'FORBIDDEN' => ApiErrorCode.forbidden,
      'VALIDATION_ERROR' => ApiErrorCode.validation,
      'NOT_FOUND' => ApiErrorCode.notFound,
      'CONFLICT' => ApiErrorCode.conflict,
      'RATE_LIMITED' => ApiErrorCode.rateLimited,
      'NETWORK_ERROR' => ApiErrorCode.network,
      _ => ApiErrorCode.server,
    };
