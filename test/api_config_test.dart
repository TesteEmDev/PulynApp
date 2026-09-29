import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/config/api_config.dart';

void main() {
  // Guarda contra publicar o app apontando para um servidor de desenvolvimento.
  test('ambiente padrão é de produção e usa HTTPS', () {
    expect(ApiConfig.currentEnvironment, isNot(ApiEnvironment.local));
    expect(ApiConfig.getApiBaseUrl(), startsWith('https://'));
  });

  test('ambientes de nuvem usam HTTPS', () {
    expect(ApiConfig.apiBaseUrlRender, startsWith('https://'));
    expect(ApiConfig.apiBaseUrlProd, startsWith('https://'));
  });

  test('endpoints são montados a partir da URL base', () {
    expect(ApiConfig.authLogin, '${ApiConfig.getApiBaseUrl()}/api/auth/login');
    expect(ApiConfig.getHeaders(token: 'abc')['Authorization'], 'Bearer abc');
    expect(ApiConfig.getHeaders().containsKey('Authorization'), isFalse);
  });
}
