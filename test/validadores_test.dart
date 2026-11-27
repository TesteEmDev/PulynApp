import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/utils/validadores.dart';

void main() {
  test('e-mail: obrigatório e com formato válido', () {
    expect(validarEmail(''), 'Email é obrigatório');
    expect(validarEmail(null), 'Email é obrigatório');
    expect(validarEmail('sem-arroba'), 'Email inválido');
    expect(validarEmail('a@b'), 'Email inválido');
    expect(validarEmail('ana@exemplo.com.br'), isNull);
  });

  test('senha: obrigatória e com pelo menos 6 caracteres', () {
    expect(validarSenha(''), 'Senha é obrigatória');
    expect(validarSenha('12345'), contains('mínimo 6'));
    expect(validarSenha('123456'), isNull);
  });

  test('confirmação da senha: obrigatória e igual à senha', () {
    expect(validarConfirmacaoSenha('', 'abc123'), 'Confirme a senha');
    expect(validarConfirmacaoSenha('abc124', 'abc123'), 'As senhas não conferem');
    expect(validarConfirmacaoSenha('abc123', 'abc123'), isNull);
  });

  test('nome: nome e sobrenome, sem números', () {
    expect(validarNome(''), 'Nome é obrigatório');
    expect(validarNome('A'), contains('mínimo 2'));
    expect(validarNome('Maria'), contains('nome completo'));
    expect(validarNome('Maria 2 Silva'), 'Nome não pode conter números');
    expect(validarNome('Maria Silva'), isNull);
    expect(validarNome('${'a' * 101} b'), contains('mais de 100'));
  });
}
