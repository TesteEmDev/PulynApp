import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scaffold customizado que previne sair do app quando usar back button
/// Também adiciona automaticamente a seta de voltar quando necessário
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Se tem um callback customizado, executa
        if (onBackPressed != null) {
          onBackPressed!();
          return false;
        }

        // Tenta voltar usando o router
        if (context.canPop()) {
          context.pop();
          return false;
        }

        // Se não conseguir voltar, fica no app (não sai)
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(title),
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (onBackPressed != null) {
                      onBackPressed!();
                    } else if (context.canPop()) {
                      context.pop();
                    }
                  },
                )
              : null,
          actions: actions,
        ),
        body: body,
      ),
    );
  }
}
