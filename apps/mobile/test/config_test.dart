import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn/app/config.dart';

AppConfig _cfg({String url = 'https://eduapp-api.example.com', String key = 'sb_publishable_abc'}) =>
    AppConfig(supabaseUrl: url, publishableKey: key, captchaSiteKey: '');

void main() {
  test('a normal configuration is accepted', () {
    expect(_cfg().problem(), isNull);
  });

  test('a missing or unparseable url is reported', () {
    expect(_cfg(url: '').problem(), 'missing_url');
    expect(_cfg(url: 'not a url').problem(), 'missing_url');
  });

  test('plain http is refused in release builds', () {
    expect(_cfg(url: 'http://eduapp-api.example.com').problem(), 'insecure_url');
    expect(_cfg(url: 'http://localhost:8000').problem(), 'insecure_url');
  });

  test('plain http is allowed only for local hosts in debug builds', () {
    expect(_cfg(url: 'http://localhost:8000').problem(allowLocalHttp: true), isNull);
    expect(_cfg(url: 'http://10.0.2.2:8000').problem(allowLocalHttp: true), isNull);
    expect(_cfg(url: 'http://eduapp-api.example.com').problem(allowLocalHttp: true), 'insecure_url');
  });

  test('a missing key is reported', () {
    expect(_cfg(key: '').problem(), 'missing_key');
    expect(_cfg(key: '   ').problem(), 'missing_key');
  });

  test('a secret key is refused so it can never ship inside the app', () {
    expect(_cfg(key: 'sb_secret_abc').problem(), 'secret_key');
  });

  test('the captcha is configured only when a site key is given', () {
    expect(_cfg().captchaConfigured, isFalse);
    expect(const AppConfig(supabaseUrl: 'https://x.example', publishableKey: 'k', captchaSiteKey: '0x4AAA').captchaConfigured, isTrue);
  });
}
