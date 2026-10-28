/// Pega só o código do convite do que a pessoa colou: o link completo
/// (`https://site/family/invite/<código>`, com ou sem `?` e `/` no fim) ou o próprio código.
/// Devolve string vazia se não sobrar nada.
String extractInviteToken(String entrada) {
  var codigo = entrada.trim();
  const marcador = '/family/invite/';
  final posicao = codigo.indexOf(marcador);
  if (posicao >= 0) codigo = codigo.substring(posicao + marcador.length);
  // Tira o que vem depois do código (parâmetros, âncora, barra final)
  final fim = codigo.indexOf(RegExp(r'[?#/\s]'));
  if (fim >= 0) codigo = codigo.substring(0, fim);
  return codigo;
}
