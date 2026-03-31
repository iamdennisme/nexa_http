import 'response.dart';

import 'call.dart';

abstract interface class Callback {
  void onFailure(Call call, Object error, StackTrace stackTrace);

  void onResponse(Call call, Response response);
}
