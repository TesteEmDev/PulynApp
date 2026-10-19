import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Manda cada linha de log para o Logcat do Android (tag "PulynApp"), inclusive em release.
/// O `print` do Dart não aparece no `adb logcat` de um build de release, então a ponte
/// nativa (MainActivity.kt) escreve direto no Logcat.
class NativeLogOutput extends LogOutput {
  static const _channel = MethodChannel('pulyn/logs');
  static final _ansi = RegExp(r'\x1B\[[0-9;]*m');

  @override
  void output(OutputEvent event) {
    final message = event.lines.join('\n').replaceAll(_ansi, '');
    try {
      _channel
          .invokeMethod<void>('log', {'level': event.level.name, 'message': message})
          .catchError((_) {});
    } catch (_) {
      // Sem plataforma (testes, web): fica só o console.
    }
  }
}

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,              // Sem stack trace
    errorMethodCount: 0,         // Sem stack trace em erros
    lineLength: 120,             // Linha mais comprida
    colors: true,
    printEmojis: true,
  ),
  level: Level.info,
  output: MultiOutput([ConsoleOutput(), NativeLogOutput()]),
);
