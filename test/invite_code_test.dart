import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/utils/invite_code.dart';

void main() {
  // Convite antigo: token de 64 caracteres (continua valendo até vencer)
  const antigo = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

  group('extractInviteToken', () {
    test('código de 8 dígitos: sai em maiúsculas, sem espaços nas pontas', () {
      expect(extractInviteToken('A3F09C12'), 'A3F09C12');
      expect(extractInviteToken('a3f09c12'), 'A3F09C12');
      expect(extractInviteToken('  a3f09c12 \n'), 'A3F09C12');
    });

    test('código digitado com espaço ou hífen no meio', () {
      expect(extractInviteToken('a3f0 9c12'), 'A3F09C12');
      expect(extractInviteToken('A3F0-9C12'), 'A3F09C12');
      expect(extractInviteToken('a3f0 - 9c12'), 'A3F09C12');
    });

    test('link completo: fica só o código', () {
      expect(extractInviteToken('https://app.pulyn.com.br/family/invite/A3F09C12'), 'A3F09C12');
      expect(extractInviteToken('https://app.pulyn.com.br/family/invite/a3f09c12'), 'A3F09C12');
    });

    test('link com barra final, parâmetros ou âncora', () {
      expect(extractInviteToken('https://x.com/family/invite/A3F09C12/'), 'A3F09C12');
      expect(extractInviteToken('https://x.com/family/invite/A3F09C12?origem=zap'), 'A3F09C12');
      expect(extractInviteToken('https://x.com/family/invite/A3F09C12#topo'), 'A3F09C12');
    });

    test('convite antigo (64 caracteres), em código ou link, passa como veio', () {
      expect(extractInviteToken(antigo), antigo);
      expect(extractInviteToken('https://x.com/family/invite/$antigo/'), antigo);
    });

    test('vazio ou só espaços devolve vazio', () {
      expect(extractInviteToken(''), '');
      expect(extractInviteToken('   '), '');
      expect(extractInviteToken('https://x.com/family/invite/'), '');
    });
  });

  group('isValidInviteCode', () {
    test('8 dígitos hexadecimais e convite antigo valem', () {
      expect(isValidInviteCode('A3F09C12'), isTrue);
      expect(isValidInviteCode(antigo), isTrue);
    });

    test('o que não é código não vale', () {
      for (final ruim in ['', 'A3F09C1', 'A3F09C123', 'G3F09C12', 'olá', 'tok123']) {
        expect(isValidInviteCode(extractInviteToken(ruim)), isFalse, reason: ruim);
      }
    });
  });
}
