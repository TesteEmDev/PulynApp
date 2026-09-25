import 'package:logger/logger.dart';

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,              // Sem stack trace
    errorMethodCount: 0,         // Sem stack trace em erros
    lineLength: 120,             // Linha mais comprida
    colors: true,
    printEmojis: true,
  ),
  level: Level.info,
);
