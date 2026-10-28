/// O convite é um código de 8 dígitos hexadecimais (0-9 e A-F), como A3F09C12. Convites antigos, de
/// 64 caracteres, ainda valem até vencerem; por isso códigos longos também passam.
final RegExp _codigoCurto = RegExp(r'^[0-9a-fA-F]{8}$');
const int _tamanhoMinimoAntigo = 32;

/// Pega só o código do convite do que a pessoa digitou ou colou: o código (em qualquer caixa, com
/// espaço ou hífen no meio, como "a3f0 9c12"), o link completo (`https://site/family/invite/<código>`,
/// com ou sem `?` e `/` no fim) ou um convite antigo. O código curto sai em maiúsculas.
/// Devolve string vazia se não sobrar nada.
String extractInviteToken(String entrada) {
  final texto = entrada.trim();

  final compacto = texto.replaceAll(RegExp(r'[\s-]'), '');
  if (_codigoCurto.hasMatch(compacto)) return compacto.toUpperCase();

  var codigo = texto;
  const marcador = '/family/invite/';
  final posicao = codigo.indexOf(marcador);
  if (posicao >= 0) codigo = codigo.substring(posicao + marcador.length);
  // Tira o que vem depois do código (parâmetros, âncora, barra final)
  final fim = codigo.indexOf(RegExp(r'[?#/\s]'));
  if (fim >= 0) codigo = codigo.substring(0, fim);
  return _codigoCurto.hasMatch(codigo) ? codigo.toUpperCase() : codigo;
}

/// O que sobrou de [extractInviteToken] parece um código de convite? (8 dígitos hexadecimais, ou
/// um convite antigo, longo). Serve para avisar antes de ir ao servidor, que barra quem erra muito.
bool isValidInviteCode(String codigo) => _codigoCurto.hasMatch(codigo) || codigo.length >= _tamanhoMinimoAntigo;

/// Aviso quando o que foi digitado não é um código.
const String mensagemCodigoInvalido = 'O código tem 8 caracteres: números de 0 a 9 e letras de A a F';
