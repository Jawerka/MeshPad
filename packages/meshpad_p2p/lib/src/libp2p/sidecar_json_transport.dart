/// JSON transport for libp2p sidecar routes (HTTP or FFI direct, PLAN 8.4).
abstract class SidecarJsonTransport {
  Future<dynamic> getValue(String path);

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  );

  Future<Map<String, dynamic>> getJson(String path) async {
    final value = await getValue(path);
    if (value is Map<String, dynamic>) return value;
    throw FormatException('expected JSON object from $path');
  }
}
