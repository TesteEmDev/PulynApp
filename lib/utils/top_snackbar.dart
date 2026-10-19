import 'dart:async';

import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Tipo da mensagem: define a cor (verde = sucesso, vermelho = erro, azul = informação).
enum FeedbackKind { success, error, info }

/// Mostra uma mensagem no TOPO da tela, por cima do conteúdo, e some sozinha.
///
/// Use as funções de atalho ([showSuccessSnackBar], [showErrorSnackBar], [showInfoSnackBar])
/// nas telas. O `SnackBar` do Material sempre aparece embaixo, por isso isto usa um overlay.
/// Com [actionLabel] e [onAction], aparece um botão (ex.: "Tentar de novo").
void showTopSnackBar(
  BuildContext context,
  String message, {
  FeedbackKind kind = FeedbackKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  Timer? timer;

  void close() {
    timer?.cancel();
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _TopSnackBarView(
      message: message,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction == null
          ? null
          : () {
              close();
              onAction();
            },
      onClose: close,
    ),
  );
  overlay.insert(entry);
  timer = Timer(duration, close);
}

/// Mensagem verde: ação concluída com sucesso.
void showSuccessSnackBar(BuildContext context, String message, {Duration? duration}) =>
    showTopSnackBar(context, message,
        kind: FeedbackKind.success, duration: duration ?? const Duration(seconds: 3));

/// Mensagem vermelha: a ação falhou. Pode ter um botão (ex.: "Tentar de novo").
void showErrorSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) =>
    showTopSnackBar(context, message,
        kind: FeedbackKind.error,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? const Duration(seconds: 5));

/// Mensagem azul: aviso neutro.
void showInfoSnackBar(BuildContext context, String message, {Duration? duration}) =>
    showTopSnackBar(context, message,
        kind: FeedbackKind.info, duration: duration ?? const Duration(seconds: 3));

Color _colorFor(FeedbackKind kind) => switch (kind) {
      FeedbackKind.success => PulynColors.success,
      FeedbackKind.error => PulynColors.danger,
      FeedbackKind.info => PulynColors.primary,
    };

class _TopSnackBarView extends StatelessWidget {
  final String message;
  final FeedbackKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _TopSnackBarView({
    required this.message,
    required this.kind,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(kind);
    final icon = switch (kind) {
      FeedbackKind.success => Icons.check_circle_outline_rounded,
      FeedbackKind.error => Icons.error_outline_rounded,
      FeedbackKind.info => Icons.info_outline_rounded,
    };
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: Text(actionLabel!),
                    ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.white,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
