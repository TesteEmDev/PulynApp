import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Checkbox de consentimento com a Política de Privacidade, usado nos cadastros.
/// Sem ele marcado a conta não é criada (LGPD, art. 14: consentimento específico
/// de pelo menos um dos responsáveis para os dados das crianças).
class ConsentimentoPrivacidade extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: enabled ? (novo) => onChanged(novo ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: PulynColors.primary,
      title: const Text(
        'Li e concordo com a Política de Privacidade. Autorizo o tratamento dos dados da minha conta e dos meus filhos para acompanhar o evento.',
        style: TextStyle(color: PulynColors.textSecondary, fontSize: 13, height: 1.4),
      ),
    );
  }
}
