# Migration Guide

This document gathered all breaking changes and migrations requirement between versions.

<!--
When new content need to be added to the migration guide, make sure they're following the format:
1. Add a version in the *Breaking versions* section, with a version anchor.
2. Use *Summary* and *Details* to introduce the migration.
-->

## Breaking versions

- [5.0.0](#500)
- [4.0.0](#400)

## 5.0.0

### Summary

- Adapters that extends `HttpClientAdapter` must now `implements` instead of `extends`.
- `DioError` has separate constructors and `DioErrorType` has different values.
- `DefaultHttpClientAdapter` is now named `IOHttpClientAdapter`.
- Imports are split into new libraries, which means users should import
  `dio/io.dart` for natives specific classes, and import `dio/web.dart` for web specific classes.
- `connectTimeout` and `receiveTimeout

### Details


## 4.0.0

### Details

1. **Null safety support** (Dart >= 2.12).
2. **The `Interceptor` APIs signature has changed**.
3. Rename `options.merge` to `options.copyWith`.
4. Rename `DioErrorType` enums from uppercase to camel style.
5. Delete `dio.resolve` and `dio.reject` APIs (use `handler` instead in  interceptors).
6. Class `BaseOptions`  no longer inherits from `Options` class.
7. Change `requestStream` type of `HttpClientAdapter.fetch` from `Stream<List<int>>` to `Stream<Uint8List>`.
8. Download API: Add real uri and redirect information to headers.
