import 'package:diox/diox.dart';

class CacheInterceptor extends Interceptor {
  CacheInterceptor();

  final _cache = <Uri, Response>{};

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
    Dio dio,
  ) {
    final response = _cache[options.uri];
    if (options.extra['refresh'] == true) {
      print('${options.uri}: force refresh, ignore cache! \n');
      return handler.next(options);
    } else if (response != null) {
      print('cache hit: ${options.uri} \n');
      return handler.resolve(response);
    }
    super.onRequest(options, handler, dio);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
    Dio dio,
  ) {
    _cache[response.requestOptions.uri] = response;
    super.onResponse(response, handler, dio);
  }

  @override
  void onError(
    DioError err,
    ErrorInterceptorHandler handler,
    Dio dio,
  ) {
    print('onError: $err');
    super.onError(err, handler, dio);
  }
}

void main() async {
  final dio = Dio();
  dio.options.baseUrl = 'https://pub.dev';
  dio.interceptors
    ..add(CacheInterceptor())
    ..add(LogInterceptor(requestHeader: false, responseHeader: false));

  await dio.get('/'); // second request
  await dio.get('/'); // Will hit cache
  // Force refresh
  await dio.get('/', options: Options(extra: {'refresh': true}));
}
