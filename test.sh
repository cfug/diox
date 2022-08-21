openssl s_client \
  -servername badssl.com \
  -connect badssl.com:443 < /dev/null 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256 > dio/test/_pinning.txt 2>/dev/null
openssl s_client \
  -servername httpbin.org \
  -connect httpbin.org:443 < /dev/null 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256 > plugins/http2_adapter/test/_http2_pinning.txt 2>/dev/null
cd dio
dart test --coverage=coverage .
pub run coverage:format_coverage --packages=.packages -i coverage -o coverage/lcov.info --lcov
genhtml -o coverage coverage/lcov.info
# Open in the default browser (mac):
open coverage/index.html
