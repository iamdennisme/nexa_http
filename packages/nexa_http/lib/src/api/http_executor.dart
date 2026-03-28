import 'nexa_http_request.dart';
import 'nexa_http_streamed_response.dart';

abstract interface class HttpExecutor {
  Future<NexaHttpStreamedResponse> execute(NexaHttpRequest request);

  Future<void> close();
}
