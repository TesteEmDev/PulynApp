import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Blocos visuais compartilhados pelas telas de entrada (código do convite,
/// cadastro pelo convite e cadastro simples), para elas terem o mesmo visual.

/// Cabeçalho: logo, título e subtítulo centralizados.
class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// `true` usa o logo completo (com o slogan); `false` só o nome, mais compacto.
  final bool fullLogo;

  const AuthHeader({
    required this.title,
    this.subtitle,
    this.fullLogo = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          fullLogo ? 'assets/images/logo-pulyn.png' : 'assets/images/logo-pulyn-mark.png',
          height: fullLogo ? 96 : 44,
          fit: BoxFit.contain,
          semanticLabel: 'Pulyn',
          errorBuilder: (_, _, _) => SizedBox(height: fullLogo ? 96 : 44),
        ),
        SizedBox(height: fullLogo ? 20 : 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// Faixa de informação com ícone, no tema escuro (no lugar das caixas claras).
class AuthInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? mensagem;
  final Color accent;
  final Widget? trailing;

  const AuthInfoCard({
    required this.icon,
    required this.title,
    this.mensagem,
    this.accent = PulynColors.primary,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (mensagem != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    mensagem!,
                    style: const TextStyle(
                      color: PulynColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Título de seção do formulário ("Seus dados", "Crianças"...).
class AuthSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const AuthSectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PulynColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: PulynColors.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cartão que agrupa campos de um formulário.
class AuthFormCard extends StatelessWidget {
  final List<Widget> children;

  const AuthFormCard({required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulynColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Campo de senha com botão de mostrar/ocultar.
class AuthPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final String? helperText;

  const AuthPasswordField({
    required this.controller,
    this.label = 'Senha',
    this.validator,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.helperText,
    super.key,
  });

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '••••••••',
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
    );
  }
}

/// Botão principal de largura total, com estado de carregamento dentro dele
/// (o botão continua no lugar em vez de sumir).
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          disabledBackgroundColor: PulynColors.primary.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible: em telas estreitas ou com fonte grande o texto encolhe com
                  // reticências em vez de estourar a largura do botão.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Passo numerado ("1 · A recepção revisa seu cadastro").
class AuthStep extends StatelessWidget {
  final int number;
  final String texto;

  const AuthStep({required this.number, required this.texto, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PulynColors.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: PulynColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              texto,
              style: const TextStyle(
                color: PulynColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
