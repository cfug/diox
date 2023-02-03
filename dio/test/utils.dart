import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';

/// The current server instance.
HttpServer? _server;

Encoding requiredEncodingForCharset(String charset) =>
    Encoding.getByName(charset) ??
    (throw FormatException('Unsupported encoding "$charset".'));

/// The URL for the current server instance.
Uri get serverUrl => Uri.parse('http://localhost:${_server?.port}');

/// Starts a new HTTP server.
Future<void> startServer() async {
  _server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      final path = request.uri.path;
      final response = request.response;

      if (path == '/error') {
        const content = 'error';
        response
          ..statusCode = 400
          ..contentLength = content.length
          ..write(content);
        response.close();
        return;
      }

      if (path == '/loop') {
        final n = int.parse(request.uri.query);
        response
          ..statusCode = 302
          ..headers
              .set('location', serverUrl.resolve('/loop?${n + 1}').toString())
          ..contentLength = 0;
        response.close();
        return;
      }

      if (path == '/redirect') {
        response
          ..statusCode = 302
          ..headers.set('location', serverUrl.resolve('/').toString())
          ..contentLength = 0;
        response.close();
        return;
      }

      if (path == '/no-content-length') {
        response
          ..statusCode = 200
          ..contentLength = -1
          ..write('body');
        response.close();
        return;
      }

      if (path == '/list') {
        response.headers.contentType = ContentType('application', 'json');
        response
          ..statusCode = 200
          ..contentLength = -1
          ..write('[1,2,3]');
        response.close();
        return;
      }

      if (path == '/multi-value-header') {
        response.headers.contentType = ContentType('application', 'json');
        response.headers.add(
          'x-multi-value-request-header-echo',
          request.headers.value('x-multi-value-request-header').toString(),
        );
        response
          ..statusCode = 200
          ..contentLength = -1
          ..write('');
        response.close();
        return;
      }

      if (path == '/download') {
        const content = 'I am a text file';
        response.headers.set('content-encoding', 'plain');
        response
          ..statusCode = 200
          ..contentLength = content.length
          ..write(content);

        Future.delayed(Duration(milliseconds: 300), () {
          response.close();
        });
        return;
      }

      final requestBodyBytes = await ByteStream(request).toBytes();
      final encodingName = request.uri.queryParameters['response-encoding'];
      final outputEncoding = encodingName == null
          ? ascii
          : requiredEncodingForCharset(encodingName);

      response.headers.contentType =
          ContentType('application', 'json', charset: outputEncoding.name);
      response.headers.set('single', 'value');

      dynamic requestBody;
      if (requestBodyBytes.isEmpty) {
        requestBody = null;
      } else {
        final encoding = requiredEncodingForCharset(
          request.headers.contentType?.charset ?? 'utf-8',
        );
        requestBody = encoding.decode(requestBodyBytes);
      }

      final content = <String, dynamic>{
        'method': request.method,
        'path': request.uri.path,
        'query': request.uri.query,
        'headers': {}
      };
      if (requestBody != null) content['body'] = requestBody;
      request.headers.forEach((name, values) {
        // These headers are automatically generated by dart:io, so we don't
        // want to test them here.
        if (name == 'cookie' || name == 'host') return;

        content['headers'][name] = values;
      });

      final body = json.encode(content);
      response
        ..contentLength = body.length
        ..write(body);
      response.close();
    });
}

/// Stops the current HTTP server.
void stopServer() {
  if (_server != null) {
    _server!.close();
    _server = null;
  }
}

/// A matcher for functions that throw SocketException.
final Matcher throwsSocketException =
    throwsA(const TypeMatcher<SocketException>());

/// A stream of chunks of bytes representing a single piece of data.
class ByteStream extends StreamView<List<int>> {
  ByteStream(Stream<List<int>> stream) : super(stream);

  /// Returns a single-subscription byte stream that will emit the given bytes
  /// in a single chunk.
  factory ByteStream.fromBytes(List<int> bytes) =>
      ByteStream(Stream.fromIterable([bytes]));

  /// Collects the data of this stream in a [Uint8List].
  Future<Uint8List> toBytes() {
    final completer = Completer<Uint8List>();
    final sink = ByteConversionSink.withCallback(
        (bytes) => completer.complete(Uint8List.fromList(bytes)));
    listen(sink.add,
        onError: completer.completeError,
        onDone: sink.close,
        cancelOnError: true);
    return completer.future;
  }

  /// Collect the data of this stream in a [String], decoded according to
  /// [encoding], which defaults to `UTF8`.
  Future<String> bytesToString([Encoding encoding = utf8]) =>
      encoding.decodeStream(this);

  Stream<String> toStringStream([Encoding encoding = utf8]) =>
      encoding.decoder.bind(this);
}
