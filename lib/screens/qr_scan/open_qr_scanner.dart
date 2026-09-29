import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import 'qr_scanner_screen.dart';

/// Abre o leitor de QR Code para vincular uma criança, como uma janela que sobe por
/// cima da tela atual. É o ÚNICO caminho usado pelo app para isso (home, perfil, barra
/// de baixo e pré-festa), então o comportamento é o mesmo em todos os lugares.
///
/// [onChildLinked] é chamado depois de a criança ser vinculada e a janela ter fechado.
Future<void> openQrScanner(BuildContext context, {VoidCallback? onChildLinked}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.of(sheetContext).size.height * 0.95,
      child: QRScannerScreen(
        apiUrl: ApiConfig.getApiBaseUrl(),
        onChildLinked: (child) {
          Navigator.pop(sheetContext);
          onChildLinked?.call();
        },
      ),
    ),
  );
}
