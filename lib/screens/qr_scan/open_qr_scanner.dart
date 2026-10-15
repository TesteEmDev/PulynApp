import 'package:flutter/material.dart';
import '../../widgets/qr_link_panel.dart';

/// Abre o leitor de QR Code numa janela que sobe por cima da tela atual (usado onde não
/// há espaço para o leitor dentro da própria tela: Perfil, pré-festa, lista de crianças).
/// Na home o leitor funciona dentro do próprio cartão (veja `LinkChildHero`). Os dois
/// usam o mesmo `QrLinkPanel`, então pedem a câmera e confirmam do mesmo jeito.
///
/// [onChildLinked] é chamado assim que a criança é vinculada.
Future<void> openQrScanner(BuildContext context, {VoidCallback? onChildLinked}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
      child: SingleChildScrollView(
        child: QrLinkPanel(
          framed: false,
          onLinked: (_) => onChildLinked?.call(),
          onClose: () => Navigator.pop(sheetContext),
        ),
      ),
    ),
  );
}
