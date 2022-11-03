@TestOn("vm")
import 'dart:async';
import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const _sleepDurationAfterConnectionEstablished = Duration(seconds: 5);

HttpServer? _server;

late Uri serverUrl;

Future<int> getUnusedPort() async {
  HttpServer? server;
  try {
    server = await HttpServer.bind('localhost', 0);
    return server.port;
  } finally {
    server?.close();
  }
}

void startServer() async {
  var port = await getUnusedPort();
  serverUrl = Uri.parse('http://localhost:$port');
  _server = await HttpServer.bind('localhost', port);
  _server?.listen((request) {
    const content = 'success';
    var response = request.response;

    sleep(_sleepDurationAfterConnectionEstablished);

    response
      ..statusCode = 200
      ..contentLength = content.length
      ..write(content);

    response.close();
    return;
  });
}

void stopServer() {
  if (_server != null) {
    _server!.close();
    _server = null;
  }
}

void main() {
  setUp(startServer);

  tearDown(stopServer);

  test(
      '#read_timeout - catch DioError when receiveTimeout < $_sleepDurationAfterConnectionEstablished',
      () async {
    var dio = Dio();

    dio.options
      ..baseUrl = serverUrl.toString()
      ..receiveTimeout =
          _sleepDurationAfterConnectionEstablished - Duration(seconds: 1);

    DioError error;

    try {
      await dio.get('/');
      fail('did not throw');
    } on DioError catch (e) {
      error = e;
    }

    expect(error, isNotNull);
    //print(error);
    expect(error.type == DioErrorType.receiveTimeout, isTrue);
  });

  test(
      '#read_timeout - no DioError when receiveTimeout > $_sleepDurationAfterConnectionEstablished',
      () async {
    var dio = Dio();

    dio.options
      ..baseUrl = serverUrl.toString()
      ..connectTimeout =
          _sleepDurationAfterConnectionEstablished + Duration(seconds: 1);

    DioError? error;

    try {
      await dio.get('/');
    } on DioError catch (e) {
      error = e;
      print(e.requestOptions.uri);
    }

    expect(error, isNull);
  });

  test('#read_timeout - change connectTimeout in run time ', () async {
    var dio = Dio();
    final adapter = DefaultHttpClientAdapter();
    final http = HttpClient();

    adapter.onHttpClientCreate = (_) => http;
    dio.httpClientAdapter = adapter;

    dio.options
      ..baseUrl = serverUrl.toString()
      ..connectTimeout = Duration(milliseconds: 200);

    try {
      await dio.get('/');
    } on DioError catch (e) {
      //ignore
    }

    expect(http.connectionTimeout?.inMilliseconds == 200, isTrue);

    try {
      dio.options.connectTimeout = Duration(seconds: 1);
      await dio.get('/');
    } on DioError {
      //ignore
    }
    expect(http.connectionTimeout?.inMilliseconds == 1000, isTrue);
  });
}
