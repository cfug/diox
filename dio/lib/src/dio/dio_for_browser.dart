import '../adapters/browser_adapter.dart';
import '../dio.dart';
import '../dio_mixin.dart';
import '../options.dart';

Dio createDio([BaseOptions? options]) => DioForBrowser(options);

class DioForBrowser with DioMixin implements Dio {
  /// Create Dio instance with default [Options].
  /// It's mostly just one Dio instance in your application.
  DioForBrowser([BaseOptions? options]) {
    this.options = options ?? BaseOptions();
    httpClientAdapter = BrowserHttpClientAdapter();
  }
}
