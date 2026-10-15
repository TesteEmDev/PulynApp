import 'package:flutter/material.dart';

/// Marca "Pulyn" (só o nome, sem o slogan) para usar em barras e cabeçalhos
/// pequenos. Para telas de boas-vindas (login, splash, onboarding) continua
/// valendo o logo completo em `assets/images/logo-pulyn.png`.
class PulynLogo extends StatelessWidget {
  final double height;

  const PulynLogo({this.height = 32, super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo-pulyn-mark.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Pulyn',
      // Se o asset faltar, não derruba a tela: só some a marca.
      errorBuilder: (_, _, _) => SizedBox(height: height),
    );
  }
}

/// Marca compacta para o canto direito do AppBar:
/// `AppBar(actions: const [PulynAppBarLogo()])`.
class PulynAppBarLogo extends StatelessWidget {
  const PulynAppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 16),
      child: Center(child: PulynLogo(height: 26)),
    );
  }
}
