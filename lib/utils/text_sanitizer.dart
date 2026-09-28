/// Remove surrogates UTF-16 sem par (órfãos), que fazem o Flutter lançar
/// "Invalid argument(s): string is not well-formed UTF-16" ao medir/renderizar
/// um Text ou ao serializar a string com jsonEncode/utf8.encode.
///
/// Esses códigos inválidos normalmente vêm de dados salvos com problema de
/// codificação (ex.: emoji truncado) em algum campo de texto vindo da API.
String sanitizeUtf16(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final unit = input.codeUnitAt(i);

    if (unit >= 0xD800 && unit <= 0xDBFF) {
      // High surrogate: só é válido se for seguido de um low surrogate.
      final next = i + 1 < input.length ? input.codeUnitAt(i + 1) : null;
      if (next != null && next >= 0xDC00 && next <= 0xDFFF) {
        buffer.writeCharCode(unit);
        buffer.writeCharCode(next);
        i++;
      }
      // Caso contrário, descarta o surrogate órfão.
      continue;
    }

    if (unit >= 0xDC00 && unit <= 0xDFFF) {
      // Low surrogate sem high surrogate antes: descarta.
      continue;
    }

    buffer.writeCharCode(unit);
  }
  return buffer.toString();
}

/// Versão que aceita nulo e retorna [fallback] se o resultado ficar vazio.
String? sanitizeUtf16OrNull(String? input) {
  if (input == null) return null;
  return sanitizeUtf16(input);
}
