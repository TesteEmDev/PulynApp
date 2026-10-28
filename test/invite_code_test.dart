import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/utils/invite_code.dart';

void main() {
  const codigo = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

  test('o próprio código passa como está (sem espaços nas pontas)', () {
    expect(extractInviteToken(codigo), codigo);
    expect(extractInviteToken('  $codigo \n'), codigo);
  });

  test('link completo: fica só o código', () {
    expect(extractInviteToken('https://app.pulyn.com.br/family/invite/$codigo'), codigo);
  });

  test('link com barra final, parâmetros ou âncora', () {
    expect(extractInviteToken('https://x.com/family/invite/$codigo/'), codigo);
    expect(extractInviteToken('https://x.com/family/invite/$codigo?origem=zap'), codigo);
    expect(extractInviteToken('https://x.com/family/invite/$codigo#topo'), codigo);
  });

  test('vazio ou só espaços devolve vazio', () {
    expect(extractInviteToken(''), '');
    expect(extractInviteToken('   '), '');
    expect(extractInviteToken('https://x.com/family/invite/'), '');
  });
}
