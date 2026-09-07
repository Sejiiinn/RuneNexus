import 'dart:convert';
import 'dart:io';

Future<String> readUpdateManifest(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await (() async {
      var target = uri;
      for (var redirects = 0; redirects <= 5; redirects++) {
        if (target.scheme != 'https' || target.userInfo.isNotEmpty) {
          throw const FormatException('업데이트 주소는 HTTPS여야 합니다.');
        }
        final request = await client.getUrl(target);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        final response = await request.close();
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) throw const FormatException('잘못된 이동 주소');
          target = target.resolve(location);
          await response.drain<void>();
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('업데이트 확인 실패: ${response.statusCode}');
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 65536) {
            throw const FormatException('업데이트 정보 크기 초과');
          }
        }
        return utf8.decode(bytes);
      }
      throw const FormatException('업데이트 주소 이동 횟수 초과');
    })().timeout(const Duration(seconds: 15));
  } finally {
    client.close(force: true);
  }
}
