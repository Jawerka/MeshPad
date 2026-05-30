import 'package:meshpad_api_client/meshpad_api_client.dart';
import 'package:meshpad_core/meshpad_core.dart';

String userFacingError(Object error) {
  if (error is MeshPadException) return error.message;
  if (error is MeshPadApiException) return error.message;
  return meshPadExceptionUserMessage(error);
}
