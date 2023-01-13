import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import 'adapter.dart';
import 'headers.dart';
import 'options.dart';
import 'utils.dart';

/// [Transformer] allows changes to the request/response data before
/// it is sent/received to/from the server.
///
/// Dio has already implemented a [DefaultTransformer], and as the default
/// [Transformer]. If you want to custom the transformation of
/// request/response data, you can provide a [Transformer] by your self, and
/// replace the [DefaultTransformer] by setting the [dio.Transformer].
abstract class Transformer {
  /// `transformRequest` allows changes to the request data before it is
  /// sent to the server, but **after** the [RequestInterceptor].
  ///
  /// This is only applicable for request methods 'PUT', 'POST', and 'PATCH'
  Future<String> transformRequest(RequestOptions options);

  /// `transformResponse` allows changes to the response data  before
  /// it is passed to [ResponseInterceptor].
  ///
  /// **Note**: As an agreement, you must return the [response]
  /// when the Options.responseType is [ResponseType.stream].
  Future transformResponse(RequestOptions options, ResponseBody response);

  /// Deep encode the [Map<String, dynamic>] to percent-encoding.
  /// It is mostly used with the "application/x-www-form-urlencoded" content-type.
  static String urlEncodeMap(
    Map map, [
    ListFormat listFormat = ListFormat.multi,
  ]) {
    return encodeMap(
      map,
      (key, value) {
        if (value == null) return key;
        return '$key=${Uri.encodeQueryComponent(value.toString())}';
      },
      listFormat: listFormat,
    );
  }

  /// Following: https://mimesniff.spec.whatwg.org/#json-mime-type
  static bool isJsonMimeType(String? contentType) {
    if (contentType == null) return false;
    final mediaType = MediaType.parse(contentType);
    return mediaType.mimeType == 'application/json' ||
        mediaType.mimeType == 'text/json' ||
        mediaType.subtype.endsWith('+json');
  }
}

/// The callback definition for decoding a JSON string.
typedef JsonDecodeCallback = FutureOr<dynamic> Function(String);

/// The callback definition for encoding a JSON object.
typedef JsonEncodeCallback = FutureOr<String> Function(Object);

/// The default [Transformer] for [Dio].
///
/// If you want to custom the transformation of request/response data,
/// you can provide a [Transformer] by your self, and replace
/// the [DefaultTransformer] by setting the [dio.transformer].
class DefaultTransformer extends Transformer {
  DefaultTransformer({
    this.jsonDecodeCallback = jsonDecode,
    this.jsonEncodeCallback = jsonEncode,
  });

  JsonDecodeCallback jsonDecodeCallback;
  JsonEncodeCallback jsonEncodeCallback;

  @override
  Future<String> transformRequest(RequestOptions options) async {
    final data = options.data ?? '';
    if (data is! String) {
      if (Transformer.isJsonMimeType(options.contentType)) {
        return jsonEncodeCallback(options.data);
      } else if (data is Map) {
        options.contentType =
            options.contentType ?? Headers.formUrlEncodedContentType;
        return Transformer.urlEncodeMap(data);
      }
    }
    return data.toString();
  }

  /// As an agreement, we return the [response] when the
  /// Options.responseType is [ResponseType.stream].
  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody response,
  ) async {
    if (options.responseType == ResponseType.stream) {
      return response;
    }
    int length = 0;
    int received = 0;
    final showDownloadProgress = options.onReceiveProgress != null;
    if (showDownloadProgress) {
      length = int.parse(
        response.headers[Headers.contentLengthHeader]?.first ?? '-1',
      );
    }
    final completer = Completer();
    final stream = response.stream.transform<Uint8List>(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
          if (showDownloadProgress) {
            received += data.length;
            options.onReceiveProgress?.call(received, length);
          }
        },
      ),
    );
    // Keep references to the data chunks and concatenate them later.
    final chunks = <Uint8List>[];
    int finalSize = 0;
    final StreamSubscription subscription = stream.listen(
      (chunk) {
        finalSize += chunk.length;
        chunks.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        completer.completeError(error, stackTrace);
      },
      onDone: () => completer.complete(),
      cancelOnError: true,
    );
    options.cancelToken?.whenCancel.then((_) {
      return subscription.cancel();
    });
    await completer.future;
    // Copy all chunks into a final Uint8List.
    final responseBytes = Uint8List(finalSize);
    int chunkOffset = 0;
    for (final chunk in chunks) {
      responseBytes.setAll(chunkOffset, chunk);
      chunkOffset += chunk.length;
    }

    if (options.responseType == ResponseType.bytes) {
      return responseBytes;
    }

    final String? responseBody;
    if (options.responseDecoder != null) {
      responseBody = options.responseDecoder!(
        responseBytes,
        options,
        response..stream = Stream.empty(),
      );
    } else if (responseBytes.isNotEmpty) {
      responseBody = utf8.decode(responseBytes, allowMalformed: true);
    } else {
      responseBody = null;
    }
    if (responseBody != null &&
        responseBody.isNotEmpty &&
        options.responseType == ResponseType.json &&
        Transformer.isJsonMimeType(
          response.headers[Headers.contentTypeHeader]?.first,
        )) {
      return jsonDecodeCallback(responseBody);
    }
    return responseBody;
  }
}
