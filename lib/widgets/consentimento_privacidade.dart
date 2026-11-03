import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

/// Checkbox de consentimento com a Política de Privacidade, usado nos cadastros.
/// Sem ele marcado a conta não é criada (LGPD, art. 14: consentimento específico
/// de pelo menos um dos responsáveis para os dados das crianças).
/// O nome "Política de Privacidade" abre a leitura dentro do app.
class ConsentimentoPrivacidade extends StatefulWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const ConsentimentoPrivacidade({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  @override
  State<ConsentimentoPrivacidade> createState() => _ConsentimentoPrivacidadeState();
}

class _ConsentimentoPrivacidadeState extends State<ConsentimentoPrivacidade> {
  late final TapGestureRecognizer _abrirPolitica = TapGestureRecognizer()
    ..onTap = () => context.push('/politica-privacidade');

  @override
  void dispose() {
    _abrirPolitica.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estiloTexto = TextStyle(color: PulynColors.textSecondary, fontSize: 13, height: 1.4);
    return CheckboxListTile(
      value: widget.value,
      onChanged: widget.enabled ? (novo) => widget.onChanged(novo ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: PulynColors.primary,
      title: Text.rich(
        TextSpan(
          style: estiloTexto,
          children: [
            const TextSpan(text: 'Li e concordo com a '),
            TextSpan(
              text: 'Política de Privacidade',
              style: const TextStyle(
                color: PulynColors.primary,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
              recognizer: _abrirPolitica,
            ),
            const TextSpan(
              text: '. Autorizo o tratamento dos dados da minha conta e dos meus filhos para acompanhar o evento.',
            ),
          ],
        ),
      ),
    );
  }
}
