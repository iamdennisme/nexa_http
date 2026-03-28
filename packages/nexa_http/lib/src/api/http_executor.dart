import 'nexa_http_request.dart';
import 'nexa_http_response.dart';

abstract interface class HttpExecutor {
  Future<NexaHttpResponse> execute(NexaHttpRequest request);

  Future<void> close();
}
