class MeshPadApiException implements Exception {
  const MeshPadApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'MeshPadApiException($code): $message';

  factory MeshPadApiException.fromResponse(int statusCode, String body) {
    return MeshPadApiException(
      'api_error',
      'Ошибка API ($statusCode): $body',
      statusCode: statusCode,
    );
  }
}
