import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/top_snackbar.dart';

/// Para as telas raiz (login, início, onboarding): o botão voltar do celular avisa
/// "Clique novamente para sair do app" e só fecha o app no segundo toque, em até 2 segundos.
///
/// Precisa ficar DENTRO da rota (em volta da tela), e não acima do navegador. Acima dele o Android
/// não enxerga o bloqueio e fecha o app no primeiro toque.
class DuploVoltarParaSair extends StatefulWidget {
  final Widget child;

  /// Quem fecha o app. Só muda nos testes.
  final VoidCallback? aoSair;

  const DuploVoltarParaSair({super.key, required this.child, this.aoSair});

  static const intervalo = Duration(seconds: 2);

  @override
  State<DuploVoltarParaSair> createState() => _DuploVoltarParaSairState();
}

class _DuploVoltarParaSairState extends State<DuploVoltarParaSair> {
  DateTime? _ultimoToque;

  void _aoVoltar(bool didPop, Object? result) {
    if (didPop) return;

    final agora = DateTime.now();
    final ultimo = _ultimoToque;
    if (ultimo != null && agora.difference(ultimo) <= DuploVoltarParaSair.intervalo) {
      (widget.aoSair ?? SystemNavigator.pop)();
      return;
    }

    _ultimoToque = agora;
    showInfoSnackBar(
      context,
      'Clique novamente para sair do app',
      duration: DuploVoltarParaSair.intervalo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _aoVoltar,
      child: widget.child,
    );
  }
}
